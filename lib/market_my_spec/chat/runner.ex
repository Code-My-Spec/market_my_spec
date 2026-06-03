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

  alias MarketMySpec.Repo
  alias MarketMySpec.Chat.{ActiveTasks, Conversation, Message, NullToolRegistry}

  @pubsub MarketMySpec.PubSub
  @task_supervisor MarketMySpec.Chat.TaskSupervisor

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
  Start streaming a reply for `conversation` in a supervised task. Returns
  immediately; the caller observes progress over PubSub.
  """
  @spec run(Conversation.t()) :: {:ok, pid()} | {:error, term()}
  def run(%Conversation{} = conversation) do
    Task.Supervisor.start_child(@task_supervisor, fn -> stream(conversation) end)
  end

  @doc """
  Run the streaming loop synchronously (used by `run/1` inside the task, and
  directly in tests). Builds history, registers an assistant placeholder, and
  streams to completion or error.
  """
  @spec stream(Conversation.t()) :: :ok
  def stream(%Conversation{} = conversation) do
    history = build_history(conversation)
    assistant = start_assistant(conversation)
    ActiveTasks.track(conversation.id, assistant.id)
    run_stream(conversation, assistant, history)
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
        finalize(conversation, assistant, acc, real_metadata(conversation, response))

      {:error, reason} ->
        fail(conversation, assistant, normalize_error(reason))
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

  defp handle_chunk(%{type: :tool_call} = chunk, conversation, _assistant, acc) do
    # v0-unreachable with the empty registry. Dispatch through the registry and
    # log; the continuation is then driven by the next provider turn.
    _result = dispatch_tool(conversation, chunk.name, chunk.arguments)
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

  defp fixture_stream(conversation, assistant, %{tool_calls: tool_calls} = fixture) do
    Enum.each(tool_calls, fn call ->
      dispatch_tool(conversation, call[:name], call[:arguments] || %{})
    end)

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
    # Leave the reply in-flight so reconnect/progressive-render specs can
    # observe the partial state held in ActiveTasks.
    Process.sleep(:infinity)
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

  defp dispatch_tool(_conversation, name, arguments) do
    case registry_tool_result(name) do
      nil ->
        Logger.debug("chat tool #{inspect(name)} dispatched with #{inspect(arguments)}")
        nil

      result ->
        result
    end
  end

  # In the v0 real path the registry returns no tools, so this is unreachable.
  # The test seam supplies tool results via :chat_tool_registry.
  defp registry_tool_result(name) do
    Application.get_env(:market_my_spec, :chat_tool_registry, %{})
    |> Map.get(:tools, [])
    |> Enum.find_value(fn tool -> if tool[:name] == name, do: tool[:result] end)
  end

  defp registry do
    Application.get_env(:market_my_spec, :chat_tool_registry_module, NullToolRegistry)
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
