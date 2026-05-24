defmodule MarketMySpec.Integrations.Providers.Codemyspec do
  @moduledoc """
  CodeMySpec OAuth provider implementation.

  Connects to the CodeMySpec platform for issue reporting and feedback.

  Configure in your runtime config:

      config :market_my_spec,
        codemyspec_url: System.get_env("CODEMYSPEC_URL") || "https://codemyspec.com",
        codemyspec_client_id: System.get_env("CODEMYSPEC_CLIENT_ID"),
        codemyspec_client_secret: System.get_env("CODEMYSPEC_CLIENT_SECRET")
  """

  require Logger

  @behaviour MarketMySpec.Integrations.Providers.Behaviour

  @callback_path "/integrations/oauth/callback/codemyspec"

  @impl true
  def callback_path, do: @callback_path

  @impl true
  def config(redirect_uri) do
    base_url = Application.fetch_env!(:market_my_spec, :codemyspec_url)
    client_id = Application.fetch_env!(:market_my_spec, :codemyspec_client_id)
    client_secret = Application.fetch_env!(:market_my_spec, :codemyspec_client_secret)

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      base_url: base_url,
      authorize_url: "#{base_url}/oauth/authorize",
      token_url: "#{base_url}/oauth/token",
      user_url: "#{base_url}/api/me",
      authorization_params: [
        scope: "read write"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.OAuth2

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    {:ok,
     %{
       provider_user_id: Map.get(user_data, "id") |> to_string(),
       email: Map.get(user_data, "email"),
       name: Map.get(user_data, "email"),
       username: Map.get(user_data, "email"),
       avatar_url: nil
     }}
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}
end
