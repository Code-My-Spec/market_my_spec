defmodule MarketMySpecWeb.ChatLive.Index do
  @moduledoc """
  The chats index — a plain table of the account's conversations (R: chats
  index, story 744). Clicking a row opens that chat (`ChatLive.Show`); "New
  chat" picks a type (problem_discovery | marketing_strategy, story 745),
  creates the conversation, and navigates straight into it.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Chat

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto w-full max-w-4xl">
        <header class="flex items-center justify-between gap-3 pb-4">
          <h1 class="text-2xl font-semibold">Chats</h1>

          <details class="relative" data-test="new-chat-menu">
            <summary class="btn btn-primary btn-sm list-none [&::-webkit-details-marker]:hidden">
              <.icon name="hero-plus" class="size-4" /> New chat
            </summary>
            <ul class="menu absolute right-0 top-full z-30 mt-1 w-max rounded-box bg-base-200 p-2 shadow [&_li>button]:whitespace-nowrap">
              <li>
                <button
                  type="button"
                  phx-click="new_chat"
                  phx-value-type="problem_discovery"
                  data-test="new-chat-problem_discovery"
                >
                  Problem Discovery
                </button>
              </li>
              <li>
                <button
                  type="button"
                  phx-click="new_chat"
                  phx-value-type="marketing_strategy"
                  data-test="new-chat-marketing_strategy"
                >
                  Marketing Strategy
                </button>
              </li>
            </ul>
          </details>
        </header>

        <table class="table" data-test="chats-table">
          <thead>
            <tr>
              <th>Chat</th>
              <th>Type</th>
              <th>Last active</th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@conversations == []} data-test="chats-empty">
              <td colspan="3" class="text-center opacity-60">No chats yet</td>
            </tr>
            <tr
              :for={c <- @conversations}
              data-test="chat-row"
              phx-click="open_chat"
              phx-value-id={c.id}
              class="cursor-pointer hover"
            >
              <td data-test="chat-list-item">{Chat.conversation_label(c)}</td>
              <td>
                <span :if={c.type} class="badge badge-outline badge-sm">{Chat.type_label(c.type)}</span>
              </td>
              <td class="text-sm opacity-70">{Calendar.strftime(c.updated_at, "%Y-%m-%d %H:%M")}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_conversations(socket)}
  end

  @impl true
  def handle_event("open_chat", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/chats/#{id}")}
  end

  def handle_event("new_chat", %{"type" => type}, socket) do
    conversation =
      Chat.create_conversation(socket.assigns.current_scope, String.to_existing_atom(type))

    {:noreply, push_navigate(socket, to: ~p"/app/chats/#{conversation.id}")}
  end

  defp assign_conversations(socket) do
    assign(socket, :conversations, Chat.list_conversations(socket.assigns.current_scope))
  end
end
