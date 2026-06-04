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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".ChatScroll">
        export default {
          mounted() {
            this.scroll();
            this.observer = new MutationObserver(() => this.scroll());
            this.observer.observe(this.el, { childList: true, subtree: true });
          },
          destroyed() { this.observer && this.observer.disconnect(); },
          scroll() { this.el.scrollTop = this.el.scrollHeight; }
        }
      </script>

      <div
        data-test="chat"
        data-chat-id={@conversation.id}
        data-chat-type={@conversation.type}
        style="height: calc(100dvh - 7rem)"
        class="mx-auto flex w-full max-w-3xl flex-col"
      >
        <header class="flex shrink-0 items-center justify-between gap-3 border-b border-base-300 pb-3">
          <div class="flex items-center gap-2">
            <div class="dropdown" data-test="chats-menu">
              <button tabindex="0" type="button" class="btn btn-ghost btn-xs">
                <.icon name="hero-bars-3" class="size-4" /> Chats
              </button>
              <ul
                tabindex="0"
                class="dropdown-content menu bg-base-200 rounded-box z-20 mt-1 max-h-80 w-72 flex-nowrap overflow-y-auto p-2 shadow"
              >
                <li :for={c <- @conversations}>
                  <button
                    type="button"
                    phx-click="open_chat"
                    phx-value-id={c.id}
                    data-test="chat-list-item"
                    class={["block truncate", c.id == @conversation.id && "active"]}
                  >
                    {conversation_label(c)}
                  </button>
                </li>
                <li :if={@conversations == []} class="px-2 py-1 text-xs opacity-60">No chats yet</li>
              </ul>
            </div>

            <h1 class="text-lg font-semibold">
              Chat
              <span :if={@conversation.type} class="badge badge-outline badge-sm ml-1">
                {chat_type_label(@conversation.type)}
              </span>
            </h1>
          </div>

          <div class="flex shrink-0 items-center gap-2">
            <.form for={%{}} phx-submit="new_chat" data-test="new-chat-form" class="flex items-center gap-1">
              <select name="conversation[type]" class="select select-bordered select-xs">
                <option value="problem_discovery">Problem Discovery</option>
                <option value="marketing_strategy">Marketing Strategy</option>
              </select>
              <.button type="submit" class="btn-xs">New</.button>
            </.form>
            <span data-test="token-badge" class="badge badge-neutral badge-sm">{@token_total} tokens</span>
            <span :if={@cost_total} data-test="cost-badge" class="badge badge-ghost badge-sm">
              ${format_cost(@cost_total)}
            </span>
          </div>
        </header>

        <div id="messages-scroll" phx-hook=".ChatScroll" class="min-h-0 flex-1 overflow-y-auto py-4">
          <div id="messages" phx-update="stream" class="space-y-1">
            <div :for={{dom_id, message} <- @streams.messages} id={dom_id}>
              <.render_message message={message} />
            </div>
          </div>

          <div :if={@streaming} class="chat chat-start">
            <div
              data-test="assistant-message"
              data-provider={@streaming.provider}
              data-model={@streaming.model}
              class="chat-bubble bg-base-200 text-base-content"
            >
              <div class="markdown">{Phoenix.HTML.raw(markdown(@streaming.content))}</div>
              <span
                :if={@streaming.status == :streaming}
                data-test="streaming-indicator"
                class="loading loading-dots loading-sm mt-1 opacity-70"
              />
              <div :if={@streaming.status == :error} data-test="message-error" class="alert alert-error mt-2">
                {@streaming.error_reason}
              </div>
              <button :if={@streaming.status == :error} data-test="retry-button" phx-click="retry" class="btn btn-sm mt-2">
                Retry
              </button>
            </div>
          </div>

          <div
            :if={@step_limit}
            data-test="step-limit-notice"
            class="alert alert-warning mt-2 text-sm"
          >
            Reached the tool step limit for this reply.
          </div>
        </div>

        <div class="shrink-0 border-t border-base-300 pt-3">
          <.form for={@message_form} phx-submit="send" data-test="chat-form" class="flex gap-2">
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
      </div>
    </Layouts.app>
    """
  end

  defp render_message(%{message: %Message{role: :user}} = assigns) do
    ~H"""
    <div class="chat chat-end">
      <div data-test="user-message" class="chat-bubble chat-bubble-primary whitespace-pre-wrap">
        {@message.content}
      </div>
    </div>
    """
  end

  defp render_message(%{message: %Message{role: :tool}} = assigns) do
    ~H"""
    <div
      data-test="tool-call"
      data-tool-name={@message.tool_name}
      class={[
        "rounded border px-3 py-2 text-xs font-mono",
        @message.status == :error && "border-error/50 text-error" || "border-base-300 opacity-80"
      ]}
    >
      <span class="font-semibold">{@message.tool_name}</span>
      <span class="ml-2 whitespace-pre-wrap">{@message.content}</span>
    </div>
    """
  end

  defp render_message(%{message: %Message{role: :assistant}} = assigns) do
    ~H"""
    <div class="chat chat-start">
      <div
        data-test="assistant-message"
        data-provider={@message.provider}
        data-model={@message.model}
        data-finish-reason={@message.finish_reason}
        class="chat-bubble bg-base-200 text-base-content"
      >
        <div class="markdown">{Phoenix.HTML.raw(markdown(@message.content))}</div>
        <div :if={@message.status == :error} data-test="message-error" class="alert alert-error mt-2">
          {@message.error_reason}
        </div>
        <button :if={@message.status == :error} data-test="retry-button" phx-click="retry" class="btn btn-sm mt-2">
          Retry
        </button>
      </div>
    </div>
    """
  end

  defp markdown(content) do
    MDEx.to_html!(content || "",
      extension: [strikethrough: true, table: true, autolink: true, tasklist: true],
      render: [unsafe: false]
    )
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    conversation = Chat.get_or_create_active_conversation(scope)

    socket =
      socket
      |> assign(:conversations, Chat.list_conversations(scope))
      |> load_conversation(conversation)

    {:ok, socket}
  end

  # Switch the active conversation: unsubscribe the previous topic, subscribe
  # the new one, load its messages, and reset per-conversation assigns. Shared
  # by mount, new_chat, and open_chat.
  defp load_conversation(socket, conversation) do
    previous = socket.assigns[:conversation]

    # Only (un)subscribe when the active conversation actually changes —
    # re-subscribing to the same topic would deliver every broadcast twice.
    if connected?(socket) and (is_nil(previous) or previous.id != conversation.id) do
      if previous, do: Phoenix.PubSub.unsubscribe(MarketMySpec.PubSub, Runner.topic(previous.id))
      Phoenix.PubSub.subscribe(MarketMySpec.PubSub, Runner.topic(conversation.id))
    end

    messages = Chat.list_messages(conversation)
    {streaming_messages, settled} = Enum.split_with(messages, &(&1.status == :streaming))
    {token_total, cost_total} = totals(settled)

    socket
    |> assign(:conversation, conversation)
    |> assign(:message_form, to_form(%{"content" => ""}, as: :message))
    |> assign(:streaming, restore_streaming(conversation, List.last(streaming_messages)))
    |> assign(:step_limit, false)
    |> assign(:token_total, token_total)
    |> assign(:cost_total, cost_total)
    |> stream(:messages, settled, reset: true)
  end

  defp chat_type_label(:problem_discovery), do: "Problem Discovery"
  defp chat_type_label(:marketing_strategy), do: "Marketing Strategy"
  defp chat_type_label(_), do: nil

  defp conversation_label(%{title: title}) when is_binary(title) and title != "", do: title
  defp conversation_label(%{type: type}) when not is_nil(type), do: "New #{chat_type_label(type)} chat"
  defp conversation_label(_), do: "New chat"

  @impl true
  def handle_event("send", %{"message" => %{"content" => content}}, socket) do
    case Chat.send_message(socket.assigns.conversation, content) do
      {:ok, message} ->
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:step_limit, false)
         |> assign(:conversations, Chat.list_conversations(socket.assigns.current_scope))
         |> assign(:message_form, to_form(%{"content" => ""}, as: :message))}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("new_chat", %{"conversation" => %{"type" => type}}, socket) do
    scope = socket.assigns.current_scope

    conversation =
      Chat.start_typed_chat(scope, socket.assigns.conversation, String.to_existing_atom(type))

    {:noreply,
     socket
     |> load_conversation(conversation)
     |> assign(:conversations, Chat.list_conversations(scope))}
  end

  def handle_event("open_chat", %{"id" => id}, socket) do
    case Chat.get_conversation(socket.assigns.current_scope, id) do
      nil -> {:noreply, socket}
      conversation -> {:noreply, load_conversation(socket, conversation)}
    end
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

  def handle_info({:stream_tool, _chat_id, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  def handle_info({:stream_step_limit, _chat_id}, socket) do
    {:noreply, assign(socket, :step_limit, true)}
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

  # --- formatting ---

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
