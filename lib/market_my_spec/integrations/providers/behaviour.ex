defmodule MarketMySpec.Integrations.Providers.Behaviour do
  @callback config(redirect_uri :: String.t()) :: Keyword.t()
  @callback callback_path() :: String.t()
  @callback strategy() :: module()
  @callback normalize_user(user_data :: map()) :: {:ok, map()} | {:error, term()}
  @callback revoke_token(token :: String.t()) :: :ok | {:error, term()}
  @optional_callbacks [revoke_token: 1]
end
