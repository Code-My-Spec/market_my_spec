defmodule MarketMySpecWeb.ThreadLive.Show do
  @moduledoc """
  LiveView for viewing a single thread and its staged touchpoints.

  Shows the thread content alongside any staged drafts. Staged touchpoints
  display the polished body with the embedded UTM link, a "Copy to clipboard"
  affordance, and a form for pasting the live comment URL to mark the
  touchpoint as posted.

  Route: /accounts/:account_id/threads/:thread_id

  NOTE: This is a scaffold. Real thread and touchpoint data from the
  Engagements context is pending Story 705-707.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mt-6">
        <div class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <h2 class="card-title">Thread</h2>
            <p class="text-base-content/60" data-test="thread-id">
              Thread ID: <%= @thread_id %>
            </p>

            <div class="divider">Staged Drafts</div>

            <%= if @touchpoints == [] do %>
              <p class="text-base-content/60" data-test="no-touchpoints">
                No staged drafts yet.
              </p>
            <% end %>

            <%= for touchpoint <- @touchpoints do %>
              <div class="card bg-base-200 mt-2" data-test={"touchpoint-#{touchpoint.id}"}>
                <div class="card-body">
                  <div class="flex items-center justify-between">
                    <span class="badge badge-info" data-test={"touchpoint-status-#{touchpoint.id}"}>
                      <%= touchpoint.status %>
                    </span>
                  </div>

                  <textarea
                    class="textarea textarea-bordered w-full mt-2"
                    data-test={"touchpoint-body-#{touchpoint.id}"}
                    readonly
                  ><%= touchpoint.polished_body %></textarea>

                  <button
                    class="btn btn-outline btn-sm mt-2"
                    data-test={"copy-to-clipboard-#{touchpoint.id}"}
                    phx-hook="CopyToClipboard"
                    id={"copy-btn-#{touchpoint.id}"}
                    data-content={touchpoint.polished_body}
                  >
                    Copy to clipboard
                  </button>

                  <%= if touchpoint.status == "staged" do %>
                    <form phx-submit="mark_posted" data-test={"mark-posted-form-#{touchpoint.id}"} id={"mark-posted-form-#{touchpoint.id}"} class="mt-4">
                      <input type="hidden" name="touchpoint_id" value={touchpoint.id} />
                      <div class="flex gap-2">
                        <input
                          type="url"
                          name="comment_url"
                          placeholder="Paste live comment URL here"
                          class="input input-bordered input-sm flex-1"
                        />
                        <button type="submit" class="btn btn-primary btn-sm">Mark Posted</button>
                      </div>
                    </form>
                  <% end %>

                  <%= if touchpoint.status == "posted" do %>
                    <p class="mt-2 text-success" data-test={"touchpoint-posted-url-#{touchpoint.id}"}>
                      Posted: <%= touchpoint.comment_url %>
                    </p>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"account_id" => account_id, "thread_id" => thread_id}, _session, socket) do
    current_scope = socket.assigns.current_scope

    case Accounts.get_account(current_scope, account_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Account not found")
         |> redirect(to: "/accounts")}

      _account ->
        {:ok,
         socket
         |> assign(:thread_id, thread_id)
         |> assign(:touchpoints, [])}
    end
  end

  @impl true
  def handle_event("mark_posted", %{"touchpoint_id" => tp_id, "comment_url" => comment_url}, socket) do
    touchpoints =
      Enum.map(socket.assigns.touchpoints, fn tp ->
        if tp.id == tp_id do
          Map.merge(tp, %{
            status: "posted",
            comment_url: comment_url,
            posted_at: DateTime.utc_now()
          })
        else
          tp
        end
      end)

    {:noreply,
     socket
     |> assign(:touchpoints, touchpoints)
     |> put_flash(:info, "Touchpoint marked as posted")}
  end
end
