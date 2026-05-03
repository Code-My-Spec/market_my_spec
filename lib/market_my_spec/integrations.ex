defmodule MarketMySpec.Integrations do
  require Logger

  alias MarketMySpec.Integrations.IntegrationRepository
  alias MarketMySpec.Users.Scope

  @default_providers Application.compile_env(:market_my_spec, :oauth_providers, %{})

  defdelegate get_integration(scope, provider), to: IntegrationRepository
  defdelegate list_integrations(scope), to: IntegrationRepository
  defdelegate delete_integration(scope, provider), to: IntegrationRepository
  defdelegate connected?(scope, provider), to: IntegrationRepository

  def list_providers do
    providers() |> Map.keys()
  end

  def callback_path(provider) do
    with {:ok, provider_mod} <- fetch_provider(provider) do
      {:ok, provider_mod.callback_path()}
    end
  end

  def authorize_url(provider, redirect_uri, opts \\ []) do
    with {:ok, provider_mod} <- fetch_provider(provider) do
      config = provider_mod.config(redirect_uri) ++ opts
      strategy = provider_mod.strategy()
      strategy.authorize_url(config)
    end
  end

  def handle_callback(%Scope{} = scope, provider, redirect_uri, params, session_params, opts \\ []) do
    with {:ok, provider_mod} <- fetch_provider(provider),
         config = provider_mod.config(redirect_uri) |> Keyword.put(:session_params, session_params) |> Keyword.merge(opts),
         strategy = provider_mod.strategy(),
         {:ok, %{token: token} = result} <- strategy.callback(config, params) do
      user_data = Map.get(result, :user) || %{}

      case provider_mod.normalize_user(user_data) do
        {:ok, normalized} ->
          attrs = build_integration_attrs(token, normalized)
          IntegrationRepository.upsert_integration(scope, provider, attrs)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_provider(provider) do
    case Map.fetch(providers(), provider) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, :unsupported_provider}
    end
  end

  defp providers do
    Application.get_env(:market_my_spec, :oauth_providers, @default_providers)
  end

  defp build_integration_attrs(token, normalized_user) do
    %{
      access_token: Map.get(token, "access_token"),
      refresh_token: Map.get(token, "refresh_token"),
      expires_at: calculate_expires_at(token),
      granted_scopes: parse_scopes(Map.get(token, "scope")),
      provider_metadata: Map.new(normalized_user)
    }
  end

  defp calculate_expires_at(%{"expires_in" => expires_in}) when is_integer(expires_in) do
    DateTime.add(DateTime.utc_now(), expires_in, :second)
  end
  defp calculate_expires_at(_token) do
    DateTime.add(DateTime.utc_now(), 365 * 24 * 3600, :second)
  end

  defp parse_scopes(nil), do: []
  defp parse_scopes(scopes) when is_list(scopes), do: scopes
  defp parse_scopes(scopes) when is_binary(scopes) do
    scopes |> String.split(~r/[,\s]+/) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end
end
