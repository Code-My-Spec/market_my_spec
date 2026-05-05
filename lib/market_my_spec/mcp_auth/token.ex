defmodule MarketMySpec.McpAuth.Token do
  @moduledoc """
  Wraps the OAuth token endpoint — exchanges codes for access tokens, validates
  bearer tokens for MCP requests.

  Delegates to ExOauth2Provider for token grant, revocation, and bearer-token
  authentication, keeping the rest of the MCP pipeline decoupled from the
  OAuth library surface.
  """

  @otp_app :market_my_spec

  @doc """
  Grants an access token based on the grant_type in the request params.

  Accepts the standard OAuth 2.0 request map and returns the access token on
  success or a tagged error tuple on failure.

  ## Examples

      iex> grant(%{"grant_type" => "authorization_code", "code" => "abc", ...})
      {:ok, %MarketMySpec.Oauth.AccessToken{}}

      iex> grant(%{"grant_type" => "invalid"})
      {:error, %{error: :unsupported_grant_type, ...}, 400}
  """
  @spec grant(map()) :: {:ok, struct()} | {:error, map(), integer() | atom()}
  def grant(params) do
    ExOauth2Provider.Token.grant(params, otp_app: @otp_app)
  end

  @doc """
  Revokes an access token per RFC 7009.

  ## Examples

      iex> revoke(%{"token" => "some_token", "client_id" => "...", ...})
      {:ok, %{}}

      iex> revoke(%{"token" => "bad_token"})
      {:error, %{error: :invalid_request, ...}, 400}
  """
  @spec revoke(map()) :: {:ok, struct()} | {:error, map(), integer() | atom()}
  def revoke(params) do
    ExOauth2Provider.Token.revoke(params, otp_app: @otp_app)
  end

  @doc """
  Authenticates a bearer token extracted from an MCP request.

  Returns `{:ok, access_token}` where `access_token` has its `:resource_owner`
  preloaded, or `{:error, reason}` when the token is missing, expired, or
  revoked.

  ## Examples

      iex> authenticate("valid_bearer_token")
      {:ok, %MarketMySpec.Oauth.AccessToken{resource_owner: %MarketMySpec.Users.User{}}}

      iex> authenticate("expired_or_invalid_token")
      {:error, :token_inaccessible}

      iex> authenticate(nil)
      {:error, :token_inaccessible}
  """
  @spec authenticate(binary() | nil) :: {:ok, struct()} | {:error, atom()}
  def authenticate(token) do
    ExOauth2Provider.authenticate_token(token, otp_app: @otp_app)
  end
end
