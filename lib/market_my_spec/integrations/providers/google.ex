defmodule MarketMySpec.Integrations.Providers.Google do
  @moduledoc """
  Google OAuth provider implementation using Assent.Strategy.Google.

  Configures OAuth with `email`, `profile`, and Google Analytics admin
  scopes, requesting offline access with a forced consent prompt to ensure
  a refresh token is issued. The Analytics scope is what the
  `MarketMySpec.McpServers.AnalyticsAdminServer` MCP tools use to read and
  modify GA4 custom dimensions, custom metrics, and key events on behalf
  of the user.

  Configure the client credentials in your runtime config:

      config :market_my_spec,
        google_client_id: System.get_env("GOOGLE_CLIENT_ID"),
        google_client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
  """

  require Logger

  @behaviour MarketMySpec.Integrations.Providers.Behaviour

  @callback_path "/integrations/oauth/callback/google"

  @impl true
  def callback_path, do: @callback_path

  @impl true
  def config(redirect_uri) do
    client_id = Application.fetch_env!(:market_my_spec, :google_client_id)
    client_secret = Application.fetch_env!(:market_my_spec, :google_client_secret)

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      # Login flow lets OIDC discovery overwrite this; the refresh-token flow
      # in Integrations.refresh_token/2 uses it directly because Assent's
      # OAuth2.refresh_access_token/2 does not perform discovery.
      token_url: "https://oauth2.googleapis.com/token",
      auth_method: :client_secret_post,
      authorization_params: [
        scope: "email profile https://www.googleapis.com/auth/analytics.edit",
        access_type: "offline",
        prompt: "consent"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.Google

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    with {:ok, provider_user_id} <- extract_provider_user_id(user_data) do
      email = Map.get(user_data, "email")

      {:ok,
       %{
         provider_user_id: provider_user_id,
         email: email,
         name: Map.get(user_data, "name"),
         username: email,
         avatar_url: Map.get(user_data, "picture"),
         hosted_domain: Map.get(user_data, "hd")
       }}
    end
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}

  defp extract_provider_user_id(%{"sub" => sub}) when is_binary(sub) and byte_size(sub) > 0,
    do: {:ok, sub}

  defp extract_provider_user_id(%{"sub" => sub}) when is_integer(sub),
    do: {:ok, Integer.to_string(sub)}

  defp extract_provider_user_id(%{"sub" => nil}), do: {:error, :missing_provider_user_id}
  defp extract_provider_user_id(_user_data), do: {:error, :missing_provider_user_id}
end
