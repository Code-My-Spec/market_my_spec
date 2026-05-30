defmodule MarketMySpecWeb.FeedbackWidget do
  @moduledoc """
  Floating feedback widget for reporting issues to CodeMySpec.

  Self-contained LiveComponent that checks its own connection status.
  Renders nothing if the user hasn't connected to CodeMySpec.
  No hooks, no prop-drilling, no layout attr changes needed.

  ## Usage

  Add to Layouts.app (current_scope is already passed):

      <.live_component
        module={MarketMySpecWeb.FeedbackWidget}
        id="codemyspec-feedback"
        current_scope={@current_scope}
      />
  """

  use MarketMySpecWeb, :live_component

  alias MarketMySpec.Codemyspec.Client

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if connected?(socket) && !Map.has_key?(socket.assigns, :connected) do
        connected =
          case socket.assigns[:current_scope] do
            nil -> false
            scope -> Client.connected?(scope)
          end

        socket
        |> assign(:connected, connected)
        |> assign(:expanded, false)
        |> assign(:submitted, false)
        |> assign(:error, nil)
        |> assign(:screenshot_data, nil)
        |> assign(:capturing, false)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, expanded: !socket.assigns.expanded, submitted: false, error: nil)}
  end

  @impl true
  def handle_event("capture_start", _params, socket) do
    {:noreply, assign(socket, :capturing, true)}
  end

  @impl true
  def handle_event("screenshot_captured", %{"data" => data_url}, socket) do
    {:noreply, socket |> assign(:screenshot_data, data_url) |> assign(:capturing, false)}
  end

  @impl true
  def handle_event("remove_screenshot", _params, socket) do
    {:noreply, assign(socket, :screenshot_data, nil)}
  end

  @impl true
  def handle_event("submit_feedback", params, socket) do
    title = String.trim(params["title"] || "")
    description = String.trim(params["description"] || "")
    severity = params["severity"] || "medium"

    if title == "" do
      {:noreply, assign(socket, :error, "Title is required")}
    else
      scope = socket.assigns.current_scope
      attachments = collect_attachments(scope, socket.assigns.screenshot_data)
      attrs = %{"title" => title, "description" => description, "severity" => severity}

      case Client.create_issue(scope, attrs, attachments) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:submitted, true)
           |> assign(:error, nil)
           |> assign(:screenshot_data, nil)}

        {:error, reason} ->
          {:noreply, assign(socket, :error, "Failed to submit: #{inspect(reason)}")}
      end
    end
  end

  defp collect_attachments(_scope, nil), do: []

  defp collect_attachments(scope, data_url) do
    case upload_screenshot(scope, data_url) do
      {:ok, attachment} -> [attachment]
      {:error, _} -> []
    end
  end

  defp upload_screenshot(scope, data_url) do
    with [_, base64] <- Regex.run(~r/^data:image\/png;base64,(.+)$/, data_url),
         {:ok, binary} <- Base.decode64(base64),
         {:ok, %{upload_url: url, s3_key: key}} <- Client.presign_upload(scope, "screenshot.png", "image/png") do
      case Req.put(url, body: binary, headers: [{"content-type", "image/png"}]) do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          {:ok, %{"s3_key" => key, "filename" => "screenshot.png", "content_type" => "image/png", "size" => byte_size(binary)}}

        _ ->
          {:error, :upload_failed}
      end
    else
      _ -> {:error, :invalid_screenshot}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".CmsScreenshot">
      export default {
        mounted() {
          this.el.addEventListener("click", async (e) => {
            if (!e.target.closest("[data-capture-screenshot]")) return;
            this.pushEventTo(this.el, "capture_start", {});
            try {
              const dataUrl = await window.__captureScreenshot();
              this.pushEventTo(this.el, "screenshot_captured", { data: dataUrl });
            } catch (err) {
              console.error("Screenshot capture failed:", err);
              this.pushEventTo(this.el, "screenshot_captured", { data: null });
            }
          });
        },
      }
    </script>

    <%= if Map.get(assigns, :connected, false) do %>
      <div class="fixed bottom-4 right-4 z-50" id="cms-feedback" phx-hook=".CmsScreenshot" phx-target={@myself}>
        <%= if @expanded do %>
          <div class="card bg-base-100 shadow-2xl border border-base-300 w-80">
            <div class="card-body p-4">
              <div class="flex items-center justify-between mb-2">
                <h3 class="card-title text-sm">Send Feedback</h3>
                <button phx-click="toggle" phx-target={@myself} class="btn btn-ghost btn-xs btn-circle">&times;</button>
              </div>

              <%= if @submitted do %>
                <div class="text-center py-4">
                  <div class="text-success text-lg mb-2">&#10003;</div>
                  <p class="text-sm text-base-content/70">Thanks for your feedback!</p>
                  <button phx-click="toggle" phx-target={@myself} class="btn btn-ghost btn-sm mt-2">Close</button>
                </div>
              <% else %>
                <form phx-submit="submit_feedback" phx-target={@myself} class="space-y-3">
                  <%= if @error do %>
                    <div class="alert alert-error text-xs p-2"><span>{@error}</span></div>
                  <% end %>

                  <%= if @screenshot_data do %>
                    <div class="relative">
                      <img src={@screenshot_data} class="w-full rounded border border-base-300" />
                      <button
                        type="button"
                        phx-click="remove_screenshot"
                        phx-target={@myself}
                        class="btn btn-circle btn-xs absolute top-1 right-1 btn-error"
                      >&times;</button>
                    </div>
                  <% else %>
                    <%= if @capturing do %>
                      <button type="button" class="btn btn-ghost btn-xs w-full border-dashed border-base-300" disabled>
                        <.icon name="hero-arrow-path" class="size-4 animate-spin" />
                        Capturing...
                      </button>
                    <% else %>
                      <button type="button" class="btn btn-ghost btn-xs w-full border-dashed border-base-300" data-capture-screenshot>
                        <.icon name="hero-camera" class="size-4" />
                        Capture Screenshot
                      </button>
                    <% end %>
                  <% end %>

                  <input type="text" name="title" placeholder="Brief summary" required class="input input-bordered input-sm w-full" />
                  <textarea name="description" placeholder="Describe the issue..." rows="3" class="textarea textarea-bordered textarea-sm w-full"></textarea>
                  <select name="severity" class="select select-bordered select-sm w-full">
                    <option value="low">Low</option>
                    <option value="medium" selected>Medium</option>
                    <option value="high">High</option>
                    <option value="critical">Critical</option>
                  </select>
                  <button type="submit" class="btn btn-primary btn-sm w-full">Submit Feedback</button>
                </form>
              <% end %>
            </div>
          </div>
        <% else %>
          <button phx-click="toggle" phx-target={@myself} class="btn btn-primary btn-circle shadow-lg" title="Send feedback">
            <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </button>
        <% end %>
      </div>
    <% end %>
    </div>
    """
  end
end
