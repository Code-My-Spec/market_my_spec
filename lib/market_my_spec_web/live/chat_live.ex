defmodule MarketMySpecWeb.ChatLive do
  @moduledoc """
  The conversational chat surface (lifted from livellm's ChatLive), rendered
  with `stream/3`.

  On mount it loads the active conversation's messages and checks `ActiveTasks`
  for an in-flight reply to restore partial assistant text and the in-progress
  indicator (R4), then subscribes to `"chat:\#{chat_id}"`. The header carries a
  provider/model selector (R5) and token/cost badges derived from persisted
  metadata (R6). Sending persists the user message immediately and the Runner
  streams the reply in a supervised task — the LiveView issues no synchronous
  provider call, so the input stays usable while a reply streams (R1/R3).

  `handle_info/2` consumes the PubSub contract — `:stream_chunk`,
  `:stream_reasoning`, `:stream_done`, `:stream_error` — updating the in-flight
  reply, including the recoverable error state with a retry affordance (R8).
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Chat
  alias MarketMySpec.Chat.{ActiveTasks, Message, Runner}

  @providers [:anthropic, :openai]
  @models ["claude-sonnet-4-6", "claude-opus-4-8", "gpt-5-mini", "gpt-5"]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div data-test="chat" data-chat-id={@conversation.id} class="mx-auto max-w-3xl">
        <header class="flex items-center justify-between gap-4 border-b border-base-300 pb-3">
          <h1 class="text-lg font-semibold">Chat</h1>

          <.form
            for={@model_form}
            phx-change="change_model"
            data-test="model-form"
            class="flex items-center gap-2"
          >
            <select name="conversation[provider]" class="select select-bordered select-sm">
              <option :for={p <- @providers} value={p} selected={to_string(p) == to_string(@conversation.provider)}>
                {p}
              </option>
            </select>
            <select name="conversation[model]" class="select select-bordered select-sm">
              <option :for={m <- @models} value={m} selected={m == @conversation.model}>
                {m}
              </option>
            </select>
          </.form>

          <div class="flex items-center gap-2">
            <span data-test="token-badge" class="badge badge-neutral">{@token_total} tokens</span>
            <span :if={@cost_total} data-test="cost-badge" class="badge badge-ghost">
              ${format_cost(@cost_total)}
            </span>
          </div>
        </header>

        <div id="messages" phx-update="stream" class="flex flex-col gap-3 py-4">
          <div :for={{dom_id, message} <- @streams.messages} id={dom_id}>
            <.render_message message={message} />
          </div>
        </div>

        <div :if={@streaming} class="py-2">
          <div
            data-test="assistant-message"
            data-provider={@streaming.provider}
            data-model={@streaming.model}
            class="chat-bubble whitespace-pre-wrap"
          >
            {@streaming.content}
            <span :if={@streaming.status == :streaming} data-test="streaming-indicator" class="loading loading-dots loading-xs" />
            <div :if={@streaming.status == :error} data-test="message-error" class="alert alert-error mt-2">
              {@streaming.error_reason}
            </div>
            <button :if={@streaming.status == :error} data-test="retry-button" phx-click="retry" class="btn btn-sm mt-2">
              Retry
            </button>
          </div>
        </div>

        <.form for={@message_form} phx-submit="send" data-test="chat-form" class="mt-4 flex gap-2">
          <input
            type="text"
            name="message[content]"
            value=""
            placeholder="Send a message"
            autocomplete="off"
            class="input input-bordered flex-1"
          />
          <.button type="submit">Send</.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  defp render_message(%{message: %Message{role: :user}} = assigns) do
    ~H"""
    <div data-test="user-message" class="chat-bubble chat-bubble-primary self-end whitespace-pre-wrap">
      {@message.content}
    </div>
    """
  end

  defp render_message(%{message: %Message{role: :assistant}} = assigns) do
    ~H"""
    <div
      data-test="assistant-message"
      data-provider={@message.provider}
      data-model={@message.model}
      data-finish-reason={@message.finish_reason}
      class="chat-bubble whitespace-pre-wrap"
    >
      {@message.content}
      <div :if={@message.status == :error} data-test="message-error" class="alert alert-error mt-2">
        {@message.error_reason}
      </div>
      <button :if={@message.status == :error} data-test="retry-button" phx-click="retry" class="btn btn-sm mt-2">
        Retry
      </button>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    conversation = Chat.get_or_create_active_conversation(socket.assigns.current_scope)
    messages = Chat.list_messages(conversation)
    {streaming_messages, settled} = Enum.split_with(messages, &(&1.status == :streaming))

    if connected?(socket) do
      Phoenix.PubSub.subscribe(MarketMySpec.PubSub, Runner.topic(conversation.id))
    end

    {token_total, cost_total} = totals(settled)

    socket =
      socket
      |> assign(:conversation, conversation)
      |> assign(:providers, @providers)
      |> assign(:models, @models)
      |> assign(:model_form, model_form(conversation))
      |> assign(:message_form, to_form(%{"content" => ""}, as: :message))
      |> assign(:streaming, restore_streaming(conversation, List.last(streaming_messages)))
      |> assign(:token_total, token_total)
      |> assign(:cost_total, cost_total)
      |> stream(:messages, settled)

    {:ok, socket}
  end

  @impl true
  def handle_event("send", %{"message" => %{"content" => content}}, socket) do
    case Chat.send_message(socket.assigns.conversation, content) do
      {:ok, message} ->
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:message_form, to_form(%{"content" => ""}, as: :message))}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("change_model", %{"conversation" => %{"provider" => provider, "model" => model}}, socket) do
    {:ok, conversation} =
      Chat.update_model(socket.assigns.conversation, String.to_existing_atom(provider), model)

    {:noreply,
     socket
     |> assign(:conversation, conversation)
     |> assign(:model_form, model_form(conversation))}
  end

  def handle_event("retry", _params, socket) do
    Chat.regenerate(socket.assigns.conversation)
    {:noreply, assign(socket, :streaming, nil)}
  end

  @impl true
  def handle_info({:stream_chunk, _chat_id, message_id, delta}, socket) do
    {:noreply, assign(socket, :streaming, append_chunk(socket, message_id, delta))}
  end

  def handle_info({:stream_reasoning, _chat_id, _message_id, _delta}, socket) do
    # Reasoning panel UI is deferred; accept the message without rendering it.
    {:noreply, socket}
  end

  def handle_info({:stream_done, _chat_id, message_id, metadata}, socket) do
    message = finalized_message(message_id, socket.assigns.streaming, metadata)

    {:noreply,
     socket
     |> stream_insert(:messages, message)
     |> assign(:streaming, nil)
     |> add_totals(metadata)}
  end

  def handle_info({:stream_error, _chat_id, message_id, reason}, socket) do
    {:noreply, assign(socket, :streaming, error_streaming(socket, message_id, reason))}
  end

  # --- streaming-state helpers ---

  defp restore_streaming(_conversation, nil), do: nil

  defp restore_streaming(conversation, %Message{} = message) do
    content =
      case ActiveTasks.get(conversation.id) do
        %{acc_text: acc} -> acc
        _ -> message.content
      end

    %{
      id: message.id,
      content: content,
      status: message.status,
      provider: message.provider || conversation.provider,
      model: message.model || conversation.model,
      error_reason: message.error_reason
    }
  end

  defp append_chunk(socket, message_id, delta) do
    case socket.assigns.streaming do
      %{id: ^message_id, content: content} = streaming ->
        %{streaming | content: content <> delta}

      _ ->
        %{
          id: message_id,
          content: delta,
          status: :streaming,
          provider: socket.assigns.conversation.provider,
          model: socket.assigns.conversation.model,
          error_reason: nil
        }
    end
  end

  defp error_streaming(socket, message_id, reason) do
    base =
      socket.assigns.streaming ||
        %{
          id: message_id,
          content: "",
          provider: socket.assigns.conversation.provider,
          model: socket.assigns.conversation.model
        }

    base
    |> Map.put(:status, :error)
    |> Map.put(:error_reason, reason)
  end

  defp finalized_message(message_id, streaming, metadata) do
    content = if streaming, do: streaming.content, else: ""

    %Message{
      id: message_id,
      role: :assistant,
      status: :complete,
      content: content,
      provider: metadata[:provider],
      model: metadata[:model],
      input_tokens: metadata[:input_tokens],
      output_tokens: metadata[:output_tokens],
      cost: to_decimal(metadata[:cost]),
      finish_reason: metadata[:finish_reason],
      response_id: metadata[:response_id]
    }
  end

  # --- selectors + formatting ---

  defp model_form(conversation) do
    to_form(
      %{"provider" => to_string(conversation.provider), "model" => conversation.model},
      as: :conversation
    )
  end

  defp totals(messages) do
    token_total =
      Enum.reduce(messages, 0, fn m, acc ->
        acc + (m.input_tokens || 0) + (m.output_tokens || 0)
      end)

    cost_total =
      messages
      |> Enum.map(& &1.cost)
      |> Enum.reject(&is_nil/1)
      |> sum_costs()

    {token_total, cost_total}
  end

  defp add_totals(socket, metadata) do
    tokens = (metadata[:input_tokens] || 0) + (metadata[:output_tokens] || 0)
    cost = to_decimal(metadata[:cost])

    socket
    |> update(:token_total, &(&1 + tokens))
    |> update(:cost_total, &add_cost(&1, cost))
  end

  defp sum_costs([]), do: nil
  defp sum_costs(costs), do: Enum.reduce(costs, &Decimal.add/2)

  defp add_cost(nil, nil), do: nil
  defp add_cost(nil, cost), do: cost
  defp add_cost(total, nil), do: total
  defp add_cost(total, cost), do: Decimal.add(total, cost)

  defp to_decimal(nil), do: nil
  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)

  defp format_cost(%Decimal{} = cost), do: :erlang.float_to_binary(Decimal.to_float(cost), decimals: 6)
  defp format_cost(cost) when is_number(cost), do: :erlang.float_to_binary(cost / 1, decimals: 6)
end
