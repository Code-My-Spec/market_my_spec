defmodule MarketMySpecWeb.McpAuthorizationLive do
  use MarketMySpecWeb, :live_view

  alias MarketMySpec.McpAuth.Authorization

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.marketing flash={@flash} current_scope={@current_scope}>
      <div class="max-w-md mx-auto mt-12">
        <.header>
          Authorize MCP client
          <:subtitle>Review what {@client_name} is requesting access to</:subtitle>
        </.header>

        <div class="card bg-base-100 shadow mt-8">
          <div class="card-body">
            <h3 class="card-title">Requested scopes</h3>
            <ul class="list-disc list-inside space-y-1 mt-2">
              <li :for={scope <- @scopes}>{scope}</li>
            </ul>

            <div class="card-actions justify-end mt-6">
              <.button phx-click="deny" class="btn-ghost" data-test="deny-button">Deny</.button>
              <.button phx-click="approve" class="btn-primary" data-test="approve-button">Approve</.button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.marketing>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    case Map.get(params, "decision") do
      nil ->
        handle_preauthorize(params, current_user, socket)

      "approve" ->
        handle_authorize(params, current_user, socket)

      "deny" ->
        handle_deny(params, current_user, socket)

      _other ->
        {:ok,
         socket
         |> put_flash(:error, "Unknown decision")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("approve", _params, socket) do
    current_user = socket.assigns.current_scope.user
    params = socket.assigns.params

    case Authorization.authorize(current_user, params) do
      {:redirect, redirect_uri} ->
        # Use Phoenix.LiveView.redirect/2 for external URLs (outside the Phoenix app).
        # push_navigate/2 only works for internal routes.
        {:noreply, redirect(socket, external: redirect_uri)}

      {:native_redirect, payload} ->
        {:noreply, push_event(socket, "oauth-native-redirect", payload)}

      {:error, error, _http_status} ->
        Logger.error("OAuth approve failed: #{inspect(error)}, params: #{inspect(params)}")

        {:noreply,
         socket
         |> put_flash(:error, "Authorization failed: #{inspect(error)}")
         |> push_navigate(to: "/")}
    end
  end

  def handle_event("deny", _params, socket) do
    current_user = socket.assigns.current_scope.user
    params = socket.assigns.params

    case Authorization.deny(current_user, params) do
      {:redirect, redirect_uri} ->
        {:noreply, redirect(socket, external: redirect_uri)}

      {:error, error, _http_status} ->
        Logger.error("OAuth deny failed: #{inspect(error)}, params: #{inspect(params)}")

        {:noreply,
         socket
         |> put_flash(:error, "Authorization denial failed: #{inspect(error)}")
         |> push_navigate(to: "/")}
    end
  end

  defp handle_preauthorize(params, current_user, socket) do
    case Authorization.preauthorize(current_user, params) do
      {:ok, client, scopes} ->
        {:ok,
         socket
         |> assign(:client_name, client.name)
         |> assign(:scopes, scopes)
         |> assign(:params, params)}

      {:redirect, redirect_uri} ->
        {:ok, push_navigate(socket, to: redirect_uri)}

      {:native_redirect, payload} ->
        {:ok, push_event(socket, "oauth-native-redirect", payload)}

      {:error, error, _http_status} ->
        Logger.error("OAuth preauthorize failed: #{inspect(error)}, params: #{inspect(params)}")

        {:ok,
         socket
         |> put_flash(:error, "OAuth authorization error: #{inspect(error)}")
         |> push_navigate(to: "/")}
    end
  end

  defp handle_authorize(params, current_user, socket) do
    oauth_params = Map.delete(params, "decision")

    case Authorization.authorize(current_user, oauth_params) do
      {:redirect, redirect_uri} ->
        {:ok, redirect(socket, external: redirect_uri)}

      {:native_redirect, payload} ->
        {:ok, push_event(socket, "oauth-native-redirect", payload)}

      {:error, error, _http_status} ->
        Logger.error("OAuth authorize failed: #{inspect(error)}, params: #{inspect(oauth_params)}")

        {:ok,
         socket
         |> put_flash(:error, "Authorization failed: #{inspect(error)}")
         |> push_navigate(to: "/")}
    end
  end

  defp handle_deny(params, current_user, socket) do
    oauth_params = Map.delete(params, "decision")

    case Authorization.deny(current_user, oauth_params) do
      {:redirect, redirect_uri} ->
        {:ok, redirect(socket, external: redirect_uri)}

      {:error, error, _http_status} ->
        Logger.error("OAuth deny failed: #{inspect(error)}, params: #{inspect(oauth_params)}")

        {:ok,
         socket
         |> put_flash(:error, "Authorization denial failed: #{inspect(error)}")
         |> push_navigate(to: "/")}
    end
  end
end
