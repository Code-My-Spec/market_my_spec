defmodule MarketMySpecWeb.TouchpointLive.Index do
  @moduledoc """
  Touchpoint list for the active account, filterable by state.

  Displays all touchpoints for the account, ordered newest-first. Each row
  shows a polished_body excerpt, angle, state badge, comment_url (if set),
  inserted_at, and thread title. Clicking a row navigates to
  TouchpointLive.Show.

  Optional state filter (`:staged`, `:posted`, `:abandoned`) is driven by
  a query param (`?state=staged`) or a tab click.

  Reads via `Engagements.list_touchpoints/2` (account-scoped).

  Route: /accounts/:account_id/touchpoints
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts
  alias MarketMySpec.Engagements

  @valid_states ~w(staged posted abandoned)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mt-6">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Touchpoints</h2>
            </div>

            <div class="tabs tabs-bordered mt-4" data-test="state-filter-tabs">
              <a
                class={"tab #{if @state_filter == nil, do: "tab-active"}"}
                phx-click="filter_state"
                phx-value-state=""
                data-test="filter-all"
              >
                All
              </a>
              <a
                class={"tab #{if @state_filter == :staged, do: "tab-active"}"}
                phx-click="filter_state"
                phx-value-state="staged"
                data-test="filter-staged"
              >
                Staged
              </a>
              <a
                class={"tab #{if @state_filter == :posted, do: "tab-active"}"}
                phx-click="filter_state"
                phx-value-state="posted"
                data-test="filter-posted"
              >
                Posted
              </a>
              <a
                class={"tab #{if @state_filter == :abandoned, do: "tab-active"}"}
                phx-click="filter_state"
                phx-value-state="abandoned"
                data-test="filter-abandoned"
              >
                Abandoned
              </a>
            </div>

            <table class="table mt-4" data-test="touchpoints-table">
              <thead>
                <tr>
                  <th>Body</th>
                  <th>Angle</th>
                  <th>State</th>
                  <th>Thread</th>
                  <th>Comment URL</th>
                  <th>When</th>
                </tr>
              </thead>
              <tbody>
                <%= for tp <- @touchpoints do %>
                  <tr
                    data-test={"touchpoint-row-#{tp.id}"}
                    class="hover cursor-pointer"
                    phx-click="view_touchpoint"
                    phx-value-id={tp.id}
                  >
                    <td data-test="touchpoint-body" class="max-w-xs truncate">
                      <%= truncate(tp.polished_body, 80) %>
                    </td>
                    <td data-test="touchpoint-angle" class="max-w-xs truncate">
                      <%= tp.angle %>
                    </td>
                    <td>
                      <span class={state_badge_class(tp.state)} data-test="touchpoint-state">
                        <%= tp.state %>
                      </span>
                    </td>
                    <td data-test="touchpoint-thread-title" class="max-w-xs truncate">
                      <%= thread_title(tp) %>
                    </td>
                    <td data-test="touchpoint-comment-url" class="max-w-xs truncate">
                      <%= tp.comment_url %>
                    </td>
                    <td data-test="touchpoint-inserted-at">
                      <%= format_time_ago(tp.inserted_at) %>
                    </td>
                  </tr>
                <% end %>
                <%= if @touchpoints == [] do %>
                  <tr>
                    <td colspan="6" class="text-center text-base-content/50" data-test="touchpoints-empty">
                      No touchpoints found.
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
  def mount(%{"account_id" => account_id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Accounts.get_account(current_scope, account_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found")
         |> redirect(to: ~p"/accounts")}

      account ->
        touchpoints = Engagements.list_touchpoints(current_scope, preload: [:thread])

        {:ok,
         socket
         |> assign(:account, account)
         |> assign(:touchpoints, touchpoints)
         |> assign(:state_filter, nil)}
    end
  end

  @impl true
  def handle_params(%{"state" => state}, _uri, socket)
      when state in @valid_states do
    state_atom = String.to_existing_atom(state)
    reload_touchpoints(socket, state_atom)
  end

  def handle_params(_params, _uri, socket) do
    reload_touchpoints(socket, nil)
  end

  @impl true
  def handle_event("filter_state", %{"state" => ""}, socket) do
    account_id = socket.assigns.account.id
    {:noreply, push_patch(socket, to: ~p"/accounts/#{account_id}/touchpoints")}
  end

  def handle_event("filter_state", %{"state" => state}, socket)
      when state in @valid_states do
    account_id = socket.assigns.account.id
    {:noreply, push_patch(socket, to: ~p"/accounts/#{account_id}/touchpoints?state=#{state}")}
  end

  def handle_event("filter_state", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("view_touchpoint", %{"id" => touchpoint_id}, socket) do
    account_id = socket.assigns.account.id

    {:noreply,
     push_navigate(socket, to: ~p"/accounts/#{account_id}/touchpoints/#{touchpoint_id}")}
  end

  # --- Private helpers -------------------------------------------------------

  defp reload_touchpoints(socket, nil) do
    scope = socket.assigns.current_scope
    touchpoints = Engagements.list_touchpoints(scope, preload: [:thread])

    {:noreply,
     socket
     |> assign(:touchpoints, touchpoints)
     |> assign(:state_filter, nil)}
  end

  defp reload_touchpoints(socket, state) do
    scope = socket.assigns.current_scope
    touchpoints = Engagements.list_touchpoints(scope, state: state, preload: [:thread])

    {:noreply,
     socket
     |> assign(:touchpoints, touchpoints)
     |> assign(:state_filter, state)}
  end

  defp truncate(nil, _max), do: ""

  defp truncate(text, max) when byte_size(text) <= max, do: text

  defp truncate(text, max) do
    String.slice(text, 0, max) <> "..."
  end

  defp thread_title(%{thread: %{title: title}}) when is_binary(title), do: title
  defp thread_title(_), do: ""

  defp state_badge_class(:staged), do: "badge badge-info"
  defp state_badge_class(:posted), do: "badge badge-success"
  defp state_badge_class(:abandoned), do: "badge badge-ghost"
  defp state_badge_class(_), do: "badge badge-outline"

  defp format_time_ago(nil), do: "unknown"

  defp format_time_ago(inserted_at) do
    diff = DateTime.diff(DateTime.utc_now(), inserted_at, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3_600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3_600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end
end
