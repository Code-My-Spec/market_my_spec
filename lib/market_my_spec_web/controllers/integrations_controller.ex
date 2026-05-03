defmodule MarketMySpecWeb.IntegrationsController do
  use MarketMySpecWeb, :controller

  alias MarketMySpec.Integrations
  alias MarketMySpec.Integrations.OAuthStateStore

  require Logger

  def request(conn, %{"provider" => provider_str}) do
    provider = String.to_existing_atom(provider_str)
    redirect_uri = redirect_uri(provider)

    case Integrations.authorize_url(provider, redirect_uri) do
      {:ok, %{url: url, session_params: session_params}} ->
        state = Map.get(session_params, "state") || Map.get(session_params, :state)
        if state, do: OAuthStateStore.store(state, session_params)

        conn
        |> put_session(:oauth_provider, provider)
        |> redirect(external: url)

      {:error, reason} ->
        Logger.error("Failed to generate OAuth URL for #{provider}: #{inspect(reason)}")
        conn
        |> put_flash(:error, "Failed to connect to #{format_provider(provider)}")
        |> redirect(to: "/")
    end
  end

  def callback(conn, params) do
    provider = get_session(conn, :oauth_provider)
    scope = conn.assigns.current_scope

    state = Map.get(params, "state")
    session_params = if state do
      case OAuthStateStore.fetch(state) do
        {:ok, sp} -> sp
        :error -> %{}
      end
    else
      %{}
    end

    conn = delete_session(conn, :oauth_provider)

    case Map.get(params, "error") do
      nil ->
        case Integrations.handle_callback(scope, provider, redirect_uri(provider), params, session_params) do
          {:ok, _integration} ->
            conn
            |> put_flash(:info, "Successfully connected to #{format_provider(provider)}")
            |> redirect(to: "/integrations")

          {:error, reason} ->
            Logger.error("OAuth callback failed for #{provider}: #{inspect(reason)}")
            conn
            |> put_flash(:error, "Failed to complete connection")
            |> redirect(to: "/integrations")
        end

      error ->
        conn
        |> put_flash(:error, format_oauth_error(error, params))
        |> redirect(to: "/integrations")
    end
  end

  def delete(conn, %{"provider" => provider_str}) do
    provider = String.to_existing_atom(provider_str)
    scope = conn.assigns.current_scope

    case Integrations.delete_integration(scope, provider) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Disconnected from #{format_provider(provider)}")
        |> redirect(to: "/integrations")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "No connection found")
        |> redirect(to: "/integrations")
    end
  end

  defp redirect_uri(provider) do
    case Integrations.callback_path(provider) do
      {:ok, path} -> MarketMySpecWeb.Endpoint.url() <> path
      {:error, _} -> MarketMySpecWeb.Endpoint.url() <> "/integrations/oauth/callback/#{provider}"
    end
  end

  defp format_provider(:github), do: "GitHub"
  defp format_provider(:google), do: "Google"
  defp format_provider(:facebook), do: "Facebook"
  defp format_provider(:quickbooks), do: "QuickBooks"
  defp format_provider(:codemyspec), do: "CodeMySpec"
  defp format_provider(provider), do: provider |> to_string() |> String.capitalize()

  defp format_oauth_error("access_denied", _params), do: "You denied access. Please try again if you want to connect."
  defp format_oauth_error(error, %{"error_description" => desc}), do: "OAuth error: #{desc} (#{error})"
  defp format_oauth_error(error, _params), do: "OAuth error: #{error}"
end
