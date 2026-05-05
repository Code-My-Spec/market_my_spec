defmodule MarketMySpec.Oauth.AccessGrant do
  @moduledoc false
  use Ecto.Schema
  use ExOauth2Provider.AccessGrants.AccessGrant, otp_app: :market_my_spec

  schema "oauth_access_grants" do
    access_grant_fields()

    timestamps()
  end
end
