defmodule MarketMySpec.Integrations.Providers.GitHub do
  @moduledoc """
  GitHub OAuth provider implementation using Assent.Strategy.Github.

  Configures OAuth with `user:email` and `read:user` scopes.
  Normalizes GitHub user data to the application domain model.

  Configure the client credentials in your runtime config:

      config :market_my_spec,
        github_client_id: System.get_env("GITHUB_CLIENT_ID"),
        github_client_secret: System.get_env("GITHUB_CLIENT_SECRET")
  """

  require Logger

  @behaviour MarketMySpec.Integrations.Providers.Behaviour

  @callback_path "/integrations/oauth/callback/github"

  @impl true
  def callback_path, do: @callback_path

  @impl true
  def config(redirect_uri) do
    client_id = Application.fetch_env!(:market_my_spec, :github_client_id)
    client_secret = Application.fetch_env!(:market_my_spec, :github_client_secret)

    [
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      authorization_params: [
        scope: "user:email read:user"
      ]
    ]
  end

  @impl true
  def strategy, do: Assent.Strategy.Github

  @impl true
  def normalize_user(user_data) when is_map(user_data) do
    with {:ok, provider_user_id} <- extract_provider_user_id(user_data) do
      {:ok,
       %{
         provider_user_id: provider_user_id,
         email: Map.get(user_data, "email"),
         name: Map.get(user_data, "name"),
         username: Map.get(user_data, "login"),
         avatar_url: Map.get(user_data, "avatar_url")
       }}
    end
  end

  def normalize_user(_user_data), do: {:error, :invalid_user_data}

  defp extract_provider_user_id(%{"sub" => sub}) when is_binary(sub) and byte_size(sub) > 0,
    do: {:ok, sub}

  defp extract_provider_user_id(%{"sub" => sub}) when is_integer(sub),
    do: {:ok, Integer.to_string(sub)}

  defp extract_provider_user_id(%{"id" => id}) when is_integer(id),
    do: {:ok, Integer.to_string(id)}

  defp extract_provider_user_id(%{"id" => id}) when is_binary(id),
    do: {:ok, id}

  defp extract_provider_user_id(_user_data), do: {:error, :missing_provider_user_id}
end
