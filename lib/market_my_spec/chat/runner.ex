defmodule MarketMySpec.Chat.Runner do
  @moduledoc """
  The only ReqLLM-aware module — mirrors livellm's LlmRunner.

  Runs inside a `Task.Supervisor` task so the LiveView never blocks (R3). For a
  conversation it:

    1. builds the request from prior thread history plus the conversation's
       provider/model;
    2. consults `ToolRegistry.list_tools/1` (v0: `[]`);
    3. streams via `ReqLLM.stream_text/3`, mapping each `StreamChunk` —
       `:content` to `{:stream_chunk, ...}`, `:thinking` to
       `{:stream_reasoning, ...}` — and broadcasting on `"chat:\#{chat_id}"`;
    4. on a `:tool_call` chunk, dispatches through the registry, feeds the
       result back, and continues (v0-unreachable with the empty registry);
    5. on completion, persists the assistant `Message` with normalized metadata
       and broadcasts `{:stream_done, ...}`;
    6. on a provider/stream failure, broadcasts `{:stream_error, ...}` for a
       recoverable error state (R8).

  As text accumulates it is written to `ActiveTasks` so a remounting LiveView
  can restore the partial reply (R4).

  ## Test seam

  In `:test` (and any env that sets it) the `:chat_llm` application env holds a
  fixture describing the provider's behaviour — `%{chunks: [...]}`, `:usage`,
  `:finish_reason`, `:response_id`, `:hang`, `:error`, `:crash`, or a
  `:tool_calls` + `:chunks_after_tool` script. This controls the *external*
  provider deterministically; the runner, broadcasts, persistence and
  ActiveTasks updates all run for real.
  """

  require Logger

  alias MarketMySpec.Chat.{ActiveTasks, Conversation, McpToolRegistry, Message, NullToolRegistry}
  alias MarketMySpec.Repo

  @pubsub MarketMySpec.PubSub
  @task_supervisor MarketMySpec.Chat.TaskSupervisor
  @max_tool_steps 5

  @typep metadata :: %{
           optional(:provider) => atom(),
           optional(:model) => String.t(),
           optional(:input_tokens) => integer() | nil,
           optional(:output_tokens) => integer() | nil,
           optional(:cost) => Decimal.t() | float() | nil,
           optional(:finish_reason) => String.t() | nil,
           optional(:response_id) => String.t() | nil
         }

  @doc "PubSub topic a conversation streams on."
  @spec topic(term()) :: String.t()
  def topic(chat_id), do: "chat:#{chat_id}"

  @doc """
  Start streaming a reply for `conversation`.

  In production the LLM call runs in a supervised task so the LiveView never
  blocks (R3); a crash there is reraised so the supervisor sees it. When the
  `:chat_llm` test fixture is configured the stream runs synchronously in the
  caller's process — it shares the test's DB sandbox connection and its
  broadcasts land in the LiveView's mailbox deterministically. The caller
  observes progress over PubSub either way.
  """
  @spec run(Conversation.t()) :: {:ok, pid()} | {:error, term()}
  def run(%Conversation{} = conversation) do
    case Application.get_env(:market_my_spec, :chat_llm) do
      nil ->
        Task.Supervisor.start_child(@task_supervisor, fn ->
          stream(conversation, reraise: true)
        end)

      _fixture ->
        stream(conversation, reraise: false)
        {:ok, self()}
    end
  end

  @doc """
  Run the streaming loop. Builds history, registers an assistant placeholder,
  streams to completion or error. On an unexpected crash it broadcasts the
  error and, when `:reraise` is set, reraises so the supervisor restarts.
  """
  @spec stream(Conversation.t(), keyword()) :: :ok
  def stream(%Conversation{} = conversation, opts \\ []) do
    history = build_history(conversation)
    assistant = start_assistant(conversation)
    ActiveTasks.track(conversation.id, assistant.id)

    try do
      run_stream(conversation, assistant, history)
    rescue
      exception ->
        fail(conversation, assistant, Exception.message(exception))
        if Keyword.get(opts, :reraise, false), do: reraise(exception, __STACKTRACE__), else: :ok
    end
  end

  # --- stream sources ---

  defp run_stream(conversation, assistant, history) do
    case Application.get_env(:market_my_spec, :chat_llm) do
      nil -> real_stream(conversation, assistant, history)
      fixture -> fixture_stream(conversation, assistant, fixture)
    end
  end

  defp real_stream(conversation, assistant, history) do
    model_spec = "#{conversation.provider}:#{conversation.model}"
    tools = registry().list_tools(conversation)

    case ReqLLM.stream_text(model_spec, history, tools: tools) do
      {:ok, response} ->
        acc = consume(response.stream, conversation, assistant)
        after_turn(conversation, assistant, history, tools, response, acc)

      {:error, reason} ->
        fail(conversation, assistant, normalize_error(reason))
    end
  end

  # After a real turn: finalize if no tool calls, otherwise execute the tools,
  # thread the results back, and stream a single continuation turn.
  defp after_turn(conversation, assistant, history, tools, response, acc) do
    case response_tool_calls(response) do
      [] ->
        finalize(conversation, assistant, acc, real_metadata(conversation, response))

      calls ->
        results =
          Enum.map(calls, fn call ->
            result = run_real_tool(conversation, tools, call)
            persist_tool_step(conversation, tool_call_name(call), result, tool_call_id(call))
            {call, result}
          end)

        next_history =
          history ++
            [%{role: :assistant, content: acc, tool_calls: calls}] ++
            tool_result_messages(results)

        model_spec = "#{conversation.provider}:#{conversation.model}"

        case ReqLLM.stream_text(model_spec, next_history, tools: tools) do
          {:ok, response2} ->
            acc2 = consume(response2.stream, conversation, assistant)
            finalize(conversation, assistant, acc <> acc2, real_metadata(conversation, response2))

          {:error, reason} ->
            fail(conversation, assistant, normalize_error(reason))
        end
    end
  end

  defp consume(stream, conversation, assistant) do
    Enum.reduce(stream, "", fn chunk, acc ->
      handle_chunk(chunk, conversation, assistant, acc)
    end)
  end

  defp handle_chunk(%{type: :content, text: text}, conversation, assistant, acc)
       when is_binary(text) do
    emit_content(conversation, assistant, text)
    acc <> text
  end

  defp handle_chunk(%{type: :thinking, text: text}, conversation, assistant, acc)
       when is_binary(text) do
    emit_reasoning(conversation, assistant, text)
    acc
  end

  defp handle_chunk(%{type: :tool_call}, _conversation, _assistant, acc) do
    # Tool calls are collected from the assembled response after the stream, not
    # dispatched per-chunk (the streamed arguments arrive fragmented).
    acc
  end

  defp handle_chunk(_chunk, _conversation, _assistant, acc), do: acc

  # --- test-seam fixture source ---

  defp fixture_stream(_conversation, _assistant, %{crash: true}) do
    raise "chat_llm fixture crash"
  end

  defp fixture_stream(conversation, assistant, %{error: reason}) do
    fail(conversation, assistant, reason)
  end

  defp fixture_stream(conversation, assistant, %{tool_calls_every_turn: call} = fixture) do
    run_tool_loop(conversation, assistant, call, fixture, 0)
  end

  defp fixture_stream(conversation, assistant, %{tool_calls: tool_calls} = fixture) do
    Enum.each(tool_calls, &handle_fixture_tool_call(conversation, &1))

    continuation = Map.get(fixture, :chunks_after_tool, [])
    emit_all(conversation, assistant, continuation)
    finalize_or_hang(conversation, assistant, continuation, fixture)
  end

  defp fixture_stream(conversation, assistant, fixture) do
    chunks = Map.get(fixture, :chunks, [])
    emit_all(conversation, assistant, chunks)
    finalize_or_hang(conversation, assistant, chunks, fixture)
  end

  defp emit_all(conversation, assistant, chunks) do
    Enum.each(chunks, &emit_content(conversation, assistant, &1))
  end

  defp finalize_or_hang(_conversation, _assistant, _chunks, %{hang: true}) do
    # Leave the reply in-flight: the assistant message stays :streaming and the
    # partial text lives in ActiveTasks, so reconnect / progressive-render specs
    # can observe it. (In production a genuine in-flight stream keeps the task
    # alive; here we simply stop emitting.)
    :ok
  end

  defp finalize_or_hang(conversation, assistant, chunks, fixture) do
    finalize(conversation, assistant, Enum.join(chunks), fixture_metadata(conversation, fixture))
  end

  # --- broadcasting + persistence ---

  defp emit_content(conversation, assistant, delta) do
    ActiveTasks.append(conversation.id, delta)
    broadcast(conversation.id, {:stream_chunk, conversation.id, assistant.id, delta})
  end

  defp emit_reasoning(conversation, assistant, delta) do
    broadcast(conversation.id, {:stream_reasoning, conversation.id, assistant.id, delta})
  end

  defp finalize(conversation, assistant, content, metadata) do
    {:ok, message} =
      assistant
      |> Message.changeset(finalize_attrs(content, metadata))
      |> Repo.update()

    ActiveTasks.clear(conversation.id)
    broadcast(conversation.id, {:stream_done, conversation.id, message.id, metadata})
    :ok
  end

  defp fail(conversation, assistant, reason) do
    message_text = describe_error(reason)

    {:ok, _message} =
      assistant
      |> Message.changeset(%{status: :error, error_reason: message_text})
      |> Repo.update()

    ActiveTasks.mark_error(conversation.id)
    ActiveTasks.clear(conversation.id)
    broadcast(conversation.id, {:stream_error, conversation.id, assistant.id, message_text})
    :ok
  end

  defp finalize_attrs(content, metadata) do
    metadata
    |> Map.take([:provider, :model, :input_tokens, :output_tokens, :cost, :finish_reason, :response_id])
    |> Map.merge(%{content: content, status: :complete})
  end

  defp start_assistant(conversation) do
    {:ok, message} =
      %Message{}
      |> Message.changeset(%{
        conversation_id: conversation.id,
        role: :assistant,
        status: :streaming,
        content: "",
        provider: conversation.provider,
        model: conversation.model
      })
      |> Repo.insert()

    message
  end

  defp build_history(conversation) do
    conversation
    |> Repo.preload(:messages)
    |> Map.fetch!(:messages)
    |> Enum.filter(&(&1.status == :complete))
    |> Enum.map(&%{role: &1.role, content: &1.content})
  end

  defp broadcast(chat_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, topic(chat_id), message)
  end

  # --- tool loop (story 745) ---

  # Fixture cap loop: the scripted model requests a tool every turn; stop at the
  # step cap with a final message + a step-limit notice (R4).
  defp run_tool_loop(conversation, assistant, _call, _fixture, step) when step >= @max_tool_steps do
    broadcast(conversation.id, {:stream_step_limit, conversation.id})

    finalize(conversation, assistant, "Reached the tool step limit; stopping here.", %{
      provider: conversation.provider,
      model: conversation.model,
      finish_reason: "length"
    })
  end

  defp run_tool_loop(conversation, assistant, call, fixture, step) do
    handle_fixture_tool_call(conversation, call)
    run_tool_loop(conversation, assistant, call, fixture, step + 1)
  end

  defp handle_fixture_tool_call(conversation, call) do
    result = fixture_tool_result(conversation, call)
    persist_tool_step(conversation, call[:name], result, call[:tool_call_id] || generate_call_id())
  end

  # A scripted error short-circuits; with a real registry configured the real
  # tool runs (R2); otherwise the fixture supplies the result.
  defp fixture_tool_result(_conversation, %{error: error}), do: {:error, error}

  defp fixture_tool_result(conversation, call) do
    case real_registry() do
      nil ->
        {:ok, call[:result] || "(no result)"}

      module ->
        run_real_tool(conversation, module.list_tools(conversation), %{
          name: call[:name],
          arguments: call[:arguments] || %{}
        })
    end
  end

  # The account scope is already closed over inside each tool's callback, so
  # dispatch only needs the conversation's tool list.
  defp run_real_tool(_conversation, tools, call) do
    name = tool_call_name(call)
    args = tool_call_args(call)

    case Enum.find(tools, fn tool -> tool.name == to_string(name) end) do
      nil ->
        {:error, "tool not available in this chat: #{name}"}

      tool ->
        case ReqLLM.Tool.execute(tool, stringify_keys(args)) do
          {:ok, result} -> {:ok, to_text(result)}
          {:error, reason} -> {:error, to_text(reason)}
          result -> {:ok, to_text(result)}
        end
    end
  end

  defp persist_tool_step(conversation, name, result, call_id) do
    {status, content} =
      case result do
        {:ok, text} -> {:complete, text}
        {:error, text} -> {:error, text}
      end

    {:ok, message} =
      %Message{}
      |> Message.changeset(%{
        conversation_id: conversation.id,
        role: :tool,
        status: status,
        content: content,
        tool_name: to_string(name),
        tool_call_id: to_string(call_id),
        error_reason: if(status == :error, do: content)
      })
      |> Repo.insert()

    broadcast(conversation.id, {:stream_tool, conversation.id, message})
    message
  end

  defp tool_result_messages(results) do
    Enum.map(results, fn {call, result} ->
      %{role: :tool, tool_call_id: tool_call_id(call), content: to_text_result(result)}
    end)
  end

  defp response_tool_calls(response) do
    case ReqLLM.StreamResponse.to_response(response) do
      {:ok, full} -> ReqLLM.Response.tool_calls(full)
      _ -> []
    end
  rescue
    _ -> []
  end

  defp tool_call_name(%{function: %{name: name}}), do: name
  defp tool_call_name(%{name: name}), do: name
  defp tool_call_name(call) when is_map(call), do: call[:name]

  defp tool_call_args(%{function: %{arguments: args}}), do: args
  defp tool_call_args(%{arguments: args}), do: args
  defp tool_call_args(_call), do: %{}

  defp tool_call_id(%{id: id}) when not is_nil(id), do: id
  defp tool_call_id(_call), do: generate_call_id()

  defp generate_call_id, do: "call_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp stringify_keys(other), do: other

  defp to_text({:ok, text}), do: to_text(text)
  defp to_text({:error, text}), do: to_text(text)
  defp to_text(text) when is_binary(text), do: text
  defp to_text(other), do: inspect(other)

  defp to_text_result({:ok, text}), do: to_text(text)
  defp to_text_result({:error, text}), do: to_text(text)

  defp registry do
    Application.get_env(:market_my_spec, :chat_tool_registry_module, McpToolRegistry)
  end

  # The registry to dispatch real tool execution against, or nil when the
  # fixture should supply scripted results (no real registry configured).
  defp real_registry do
    case Application.get_env(:market_my_spec, :chat_tool_registry_module) do
      nil -> nil
      NullToolRegistry -> nil
      module -> module
    end
  end

  # --- metadata normalization ---

  @spec real_metadata(Conversation.t(), ReqLLM.StreamResponse.t()) :: metadata()
  defp real_metadata(conversation, response) do
    usage = safe_usage(response)

    %{
      provider: conversation.provider,
      model: conversation.model,
      input_tokens: usage[:input_tokens],
      output_tokens: usage[:output_tokens],
      cost: usage[:total_cost],
      finish_reason: to_string_or_nil(safe_finish_reason(response)),
      response_id: nil
    }
  end

  defp fixture_metadata(conversation, fixture) do
    usage = Map.get(fixture, :usage, %{})

    %{
      provider: Map.get(fixture, :provider, conversation.provider),
      model: Map.get(fixture, :model, conversation.model),
      input_tokens: Map.get(usage, :input_tokens),
      output_tokens: Map.get(usage, :output_tokens),
      cost: Map.get(usage, :cost),
      finish_reason: Map.get(fixture, :finish_reason),
      response_id: Map.get(fixture, :response_id)
    }
  end

  defp safe_usage(response) do
    ReqLLM.StreamResponse.usage(response) || %{}
  rescue
    _ -> %{}
  end

  defp safe_finish_reason(response) do
    ReqLLM.StreamResponse.finish_reason(response)
  rescue
    _ -> nil
  end

  defp normalize_error(%{__exception__: true} = e), do: Exception.message(e)
  defp normalize_error(reason), do: reason

  @doc "Human-readable description of a stream failure reason."
  @spec describe_error(term()) :: String.t()
  def describe_error(reason) when is_binary(reason), do: reason
  def describe_error(:invalid_api_key), do: "provider auth failed"
  def describe_error(:rate_limited), do: "the provider is rate limiting requests"
  def describe_error(reason), do: inspect(reason)

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value), do: to_string(value)
end
