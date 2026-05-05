defmodule MarketMySpec.Oauth.AccessToken do
  @moduledoc false
  use Ecto.Schema
  use ExOauth2Provider.AccessTokens.AccessToken, otp_app: :market_my_spec
  import Ecto.Changeset

  schema "oauth_access_tokens" do
    access_token_fields()

    timestamps()
  end

  def changeset(access_token, attrs) do
    access_token
    |> cast(attrs, [:resource_owner_id, :application_id, :scopes, :expires_in])
    |> validate_required([:resource_owner_id, :application_id])
    |> validate_number(:expires_in, greater_than: 0)
    |> put_token_and_expiry()
  end

  defp put_token_and_expiry(changeset) do
    if changeset.valid? do
      token = generate_token()
      expires_in = get_field(changeset, :expires_in) || 7200
      expires_at = DateTime.utc_now() |> DateTime.add(expires_in, :second)

      changeset
      |> put_change(:token, token)
      |> put_change(:expires_in, expires_in)
      |> put_change(:expires_at, expires_at)
    else
      changeset
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
