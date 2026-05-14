defmodule MarketMySpecWeb.ThreadLive.Index do
  @moduledoc """
  LiveView listing recently ingested engagement threads for the active account.

  Displays threads in a table with title (truncated), source badge, venue
  identifier, time since fetched, and touchpoint count. Clicking a row
  navigates to ThreadLive.Show.

  Route: /accounts/:id/threads
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Engagements

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mt-6">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Threads</h2>
            </div>

            <table class="table mt-4" data-test="threads-table">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Source</th>
                  <th>Venue</th>
                  <th>Fetched</th>
                  <th>Touchpoints</th>
                </tr>
              </thead>
              <tbody>
                <%= for thread <- @threads do %>
                  <tr
                    data-test={"thread-row-#{thread.id}"}
                    class="hover cursor-pointer"
                    phx-click="view_thread"
                    phx-value-id={thread.id}
                  >
                    <td data-test="thread-title" class="max-w-xs truncate">
                      <%= truncate(thread.title, 80) %>
                    </td>
                    <td>
                      <span
                        class={source_badge_class(thread.source)}
                        data-test="thread-source"
                      >
                        <%= format_source(thread.source) %>
                      </span>
                    </td>
                    <td data-test="thread-venue"><%= thread.source_thread_id %></td>
                    <td data-test="thread-fetched-at"><%= format_time_ago(thread.fetched_at) %></td>
                    <td data-test="thread-touchpoint-count">
                      <%= Map.get(@touchpoint_counts, thread.id, 0) %>
                    </td>
                  </tr>
                <% end %>
                <%= if @threads == [] do %>
                  <tr>
                    <td colspan="5" class="text-center text-base-content/50" data-test="threads-empty">
                      No threads have been ingested yet.
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Accounts.get_account(current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found")
         |> redirect(to: ~p"/accounts")}

      account ->
        threads = Engagements.list_threads(current_scope)
        touchpoint_counts = build_touchpoint_counts(current_scope)

        {:ok,
         socket
         |> assign(:account, account)
         |> assign(:threads, threads)
         |> assign(:touchpoint_counts, touchpoint_counts)}
    end
  end

  @impl true
  def handle_event("view_thread", %{"id" => thread_id}, socket) do
    account_id = socket.assigns.account.id

    {:noreply,
     push_navigate(socket, to: ~p"/accounts/#{account_id}/threads/#{thread_id}")}
  end

  # --- Private helpers -------------------------------------------------------

  defp build_touchpoint_counts(scope) do
    scope
    |> Engagements.list_touchpoints()
    |> Enum.group_by(& &1.thread_id)
    |> Map.new(fn {thread_id, touchpoints} -> {thread_id, length(touchpoints)} end)
  end

  defp truncate(nil, _max), do: ""

  defp truncate(text, max) when byte_size(text) <= max, do: text

  defp truncate(text, max) do
    String.slice(text, 0, max) <> "..."
  end

  defp format_source(:reddit), do: "Reddit"
  defp format_source(:elixirforum), do: "ElixirForum"
  defp format_source(source), do: to_string(source)

  defp source_badge_class(:reddit), do: "badge badge-warning"
  defp source_badge_class(:elixirforum), do: "badge badge-info"
  defp source_badge_class(_), do: "badge badge-outline"

  defp format_time_ago(nil), do: "unknown"

  defp format_time_ago(fetched_at) do
    diff = DateTime.diff(DateTime.utc_now(), fetched_at, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3_600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3_600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end
end
