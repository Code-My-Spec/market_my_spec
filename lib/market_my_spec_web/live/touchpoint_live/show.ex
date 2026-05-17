defmodule MarketMySpecWeb.TouchpointLive.Show do
  @moduledoc """
  Single-touchpoint detail view.

  Renders polished_body, angle, state, comment_url, posted_at, link_target,
  and parent thread context. Provides three actions:

    1. Mark posted — paste live comment URL + posted_at, transitions state to
       :posted via `Engagements.update_touchpoint/3`. Rejects without comment_url.
    2. Abandon — transitions state to :abandoned via `Engagements.update_touchpoint/3`,
       preserving all other fields.
    3. Delete — hard-removes the row via `Engagements.delete_touchpoint/2`.

  The same context functions back the MCP `update_touchpoint` and
  `delete_touchpoint` tools so UI and agent surfaces produce identical
  persisted state.

  Route: /accounts/:account_id/touchpoints/:touchpoint_id
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Engagements
  alias MarketMySpec.Engagements.Touchpoint

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mt-6 max-w-3xl mx-auto space-y-6">
        <.header>
          Touchpoint Detail
          <:subtitle>
            State: <span class="badge badge-outline" data-test="touchpoint-state"><%= @touchpoint.state %></span>
          </:subtitle>
        </.header>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body space-y-4">
            <div :if={@touchpoint.angle} data-test="touchpoint-angle">
              <p class="text-sm font-semibold text-base-content/70">Angle</p>
              <p class="mt-1"><%= @touchpoint.angle %></p>
            </div>

            <div data-test="touchpoint-body">
              <p class="text-sm font-semibold text-base-content/70">Polished Body</p>
              <textarea class="textarea textarea-bordered w-full mt-1" readonly rows="6"><%= @touchpoint.polished_body %></textarea>
            </div>

            <div :if={@touchpoint.link_target} data-test="touchpoint-link-target">
              <p class="text-sm font-semibold text-base-content/70">Link Target</p>
              <p class="mt-1 text-sm font-mono break-all"><%= @touchpoint.link_target %></p>
            </div>

            <div :if={@touchpoint.comment_url} data-test="touchpoint-comment-url">
              <p class="text-sm font-semibold text-base-content/70">Comment URL</p>
              <p class="mt-1 text-sm font-mono break-all"><%= @touchpoint.comment_url %></p>
            </div>

            <div :if={@touchpoint.posted_at} data-test="touchpoint-posted-at">
              <p class="text-sm font-semibold text-base-content/70">Posted At</p>
              <p class="mt-1 text-sm"><%= @touchpoint.posted_at %></p>
            </div>
          </div>
        </div>

        <div :if={@touchpoint.state != :posted} class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <h3 class="card-title text-base">Mark as Posted</h3>
            <p class="text-sm text-base-content/70">Paste the live comment URL to record this touchpoint as posted.</p>

            <.form
              for={@mark_posted_form}
              id="mark-posted-form"
              data-test="mark-posted-form"
              phx-submit="mark_posted"
            >
              <div class="space-y-3 mt-2">
                <.input
                  field={@mark_posted_form[:comment_url]}
                  type="url"
                  label="Live Comment URL"
                  placeholder="https://www.reddit.com/r/..."
                />
                <%!-- posted_at is submitted as text so tests can inject an explicit timestamp.
                     The server defaults to DateTime.utc_now() when empty. --%>
                <input type="text" name="touchpoint[posted_at]" value="" class="hidden" />
                <.button type="submit" variant="primary" phx-disable-with="Saving...">
                  Mark Posted
                </.button>
              </div>
            </.form>
          </div>
        </div>

        <div class="flex gap-3">
          <div :if={@touchpoint.state != :abandoned}>
            <.button
              phx-click="abandon"
              data-test="abandon-button"
              class="btn btn-warning btn-outline"
            >
              Abandon
            </.button>
          </div>

          <button
            type="button"
            class="btn btn-error btn-outline"
            onclick={"document.getElementById('delete-touchpoint-modal').showModal()"}
            data-test="open-delete-modal"
          >
            Delete
          </button>
        </div>

        <.confirm_modal
          id="delete-touchpoint-modal"
          title="Delete this touchpoint?"
          body="This permanently removes the touchpoint record. This action cannot be undone."
          confirm_label="Delete"
          confirm_event="delete"
          confirm_value={%{}}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"account_id" => _account_id, "touchpoint_id" => touchpoint_id}, _session, socket) do
    scope = socket.assigns.current_scope

    case Engagements.get_touchpoint_by_id(scope, touchpoint_id) do
      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Touchpoint not found")
         |> push_navigate(to: "/accounts")}

      {:ok, touchpoint} ->
        {:ok,
         socket
         |> assign(:touchpoint, touchpoint)
         |> assign(:mark_posted_form, mark_posted_form(touchpoint))}
    end
  end

  @impl true
  def handle_event("mark_posted", %{"touchpoint" => params}, socket) do
    scope = socket.assigns.current_scope
    touchpoint = socket.assigns.touchpoint

    comment_url = Map.get(params, "comment_url", "")
    posted_at_str = Map.get(params, "posted_at", "")

    posted_at = parse_posted_at(posted_at_str)

    attrs =
      %{state: :posted, comment_url: comment_url}
      |> Map.put(:posted_at, posted_at || DateTime.utc_now() |> DateTime.truncate(:second))

    case Engagements.update_touchpoint(scope, touchpoint.id, attrs) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:touchpoint, updated)
         |> assign(:mark_posted_form, mark_posted_form(updated))
         |> put_flash(:info, "Touchpoint marked as posted")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:mark_posted_form, to_form(changeset, as: :touchpoint))
         |> put_flash(:error, "Could not mark as posted — check the URL")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Touchpoint not found")}
    end
  end

  def handle_event("abandon", _params, socket) do
    scope = socket.assigns.current_scope
    touchpoint = socket.assigns.touchpoint

    case Engagements.update_touchpoint(scope, touchpoint.id, %{state: :abandoned}) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:touchpoint, updated)
         |> assign(:mark_posted_form, mark_posted_form(updated))
         |> put_flash(:info, "Touchpoint abandoned")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not abandon touchpoint")}
    end
  end

  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope
    touchpoint = socket.assigns.touchpoint

    case Engagements.delete_touchpoint(scope, touchpoint.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Touchpoint deleted")
         |> push_navigate(to: "/accounts/#{scope.active_account_id}/threads")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Touchpoint not found")}
    end
  end

  defp mark_posted_form(%Touchpoint{} = touchpoint) do
    changeset = Touchpoint.update_changeset(touchpoint, %{})
    to_form(changeset, as: :touchpoint)
  end

  defp parse_posted_at(""), do: nil
  defp parse_posted_at(nil), do: nil

  defp parse_posted_at(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end
end
