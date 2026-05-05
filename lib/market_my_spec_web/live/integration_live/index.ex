defmodule MarketMySpecWeb.IntegrationLive.Index do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Integrations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Integrations
        <:subtitle>Connect your external services</:subtitle>
      </.header>

      <div class="mt-8 space-y-6">
        <div :if={@connected != []} class="space-y-4">
          <h3 class="text-lg font-semibold">Connected</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div :for={integration <- @connected} class="card bg-base-100 border border-success">
              <div class="card-body">
                <h2 class="card-title text-base">{format_provider(integration.provider)}</h2>
                <p class="text-sm text-success">Connected</p>
                <div class="card-actions justify-end mt-4">
                  <button
                    type="button"
                    class="btn btn-sm btn-error"
                    onclick={"document.getElementById('disconnect-modal-#{integration.provider}').showModal()"}
                    data-test={"open-disconnect-modal-#{integration.provider}"}
                  >
                    Disconnect
                  </button>
                  <.confirm_modal
                    id={"disconnect-modal-#{integration.provider}"}
                    title="Disconnect integration?"
                    body={"This will disconnect your #{format_provider(integration.provider)} integration. You can reconnect at any time."}
                    confirm_label="Disconnect"
                    confirm_event="disconnect"
                    confirm_value={%{provider: integration.provider}}
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@available != []} class="space-y-4">
          <h3 class="text-lg font-semibold">Available</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div :for={provider <- @available} class="card bg-base-100 border border-base-300">
              <div class="card-body">
                <h2 class="card-title text-base">{format_provider(provider)}</h2>
                <div class="card-actions justify-end mt-4">
                  <.link href={~p"/integrations/oauth/#{provider}"} class="btn btn-sm btn-primary">
                    Connect
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    connected = Integrations.list_integrations(scope)
    connected_providers = Enum.map(connected, & &1.provider)
    all_providers = Integrations.list_providers()
    available = Enum.reject(all_providers, &(&1 in connected_providers))

    {:ok,
     socket
     |> assign(:connected, connected)
     |> assign(:available, available)}
  end

  @impl true
  def handle_event("disconnect", %{"provider" => provider_str}, socket) do
    provider = String.to_existing_atom(provider_str)
    scope = socket.assigns.current_scope

    case Integrations.delete_integration(scope, provider) do
      {:ok, _} ->
        connected = Integrations.list_integrations(scope)
        connected_providers = Enum.map(connected, & &1.provider)
        all_providers = Integrations.list_providers()
        available = Enum.reject(all_providers, &(&1 in connected_providers))

        {:noreply,
         socket
         |> put_flash(:info, "Disconnected from #{format_provider(provider)}")
         |> assign(:connected, connected)
         |> assign(:available, available)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disconnect")}
    end
  end

  defp format_provider(:github), do: "GitHub"
  defp format_provider(:google), do: "Google"
  defp format_provider(:facebook), do: "Facebook"
  defp format_provider(:quickbooks), do: "QuickBooks"
  defp format_provider(provider), do: provider |> to_string() |> String.capitalize()
end
