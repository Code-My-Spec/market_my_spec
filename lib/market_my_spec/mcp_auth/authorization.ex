defmodule MarketMySpec.McpAuth.Authorization do
  @moduledoc """
  Wraps the OAuth authorization-grant flow — validates PKCE challenges, builds
  consent context, issues authorization codes.

  Delegates to ExOauth2Provider.Authorization for preauthorize, authorize, and
  deny operations, keeping the rest of the MCP pipeline decoupled from the
  OAuth library surface.
  """

  @otp_app :market_my_spec

  @doc """
  Pre-authorizes an OAuth request, returning the client and requested scopes
  for rendering a consent screen.

  The `resource_owner` is the authenticated user who is being asked to grant
  access. The `params` map must contain at minimum `"client_id"`,
  `"response_type"`, and `"redirect_uri"`. For MCP public clients, a
  `"code_challenge"` and `"code_challenge_method"` (S256) are required.

  ## Return values

  - `{:ok, client, scopes}` — valid request; render a consent screen
  - `{:redirect, redirect_uri}` — previously authorized; redirect immediately
  - `{:native_redirect, payload}` — for native/OOB redirect URIs
  - `{:error, error, http_status}` — invalid request params or client

  ## Examples

      iex> preauthorize(user, %{"client_id" => "...", "response_type" => "code", ...})
      {:ok, %MarketMySpec.Oauth.Application{}, ["read", "write"]}

      iex> preauthorize(user, %{"client_id" => "unknown"})
      {:error, %{error: :invalid_client, ...}, 401}
  """
  @spec preauthorize(struct(), map()) ::
          {:ok, struct(), list()}
          | {:redirect, binary()}
          | {:native_redirect, map()}
          | {:error, map(), integer() | atom()}
  def preauthorize(resource_owner, params) do
    ExOauth2Provider.Authorization.preauthorize(resource_owner, params, otp_app: @otp_app)
  end

  @doc """
  Authorizes an OAuth request after the user grants consent, issuing an
  authorization code via redirect.

  The `resource_owner` is the authenticated user granting access. The `params`
  map must contain the same fields as `preauthorize/2` plus any additional
  fields the authorization server requires.

  ## Return values

  - `{:redirect, redirect_uri}` — authorization code issued; redirect to client
  - `{:native_redirect, payload}` — for native/OOB redirect URIs
  - `{:error, error, http_status}` — grant failed

  ## Examples

      iex> authorize(user, %{"client_id" => "...", "response_type" => "code", ...})
      {:redirect, "https://client.example.com/callback?code=abc123&state=xyz"}

      iex> authorize(user, %{"client_id" => "unknown"})
      {:error, %{error: :invalid_client, ...}, 401}
  """
  @spec authorize(struct(), map()) ::
          {:redirect, binary()} | {:native_redirect, map()} | {:error, map(), integer() | atom()}
  def authorize(resource_owner, params) do
    ExOauth2Provider.Authorization.authorize(resource_owner, params, otp_app: @otp_app)
  end

  @doc """
  Denies an OAuth request, redirecting back to the client with an access_denied
  error.

  The `resource_owner` is the authenticated user denying access. The `params`
  map must contain the same fields as `preauthorize/2`.

  ## Return values

  - `{:redirect, redirect_uri}` — denial issued; redirect to client with error
  - `{:error, error, http_status}` — denial failed (e.g., invalid client)

  ## Examples

      iex> deny(user, %{"client_id" => "...", "response_type" => "code", ...})
      {:redirect, "https://client.example.com/callback?error=access_denied&state=xyz"}

      iex> deny(user, %{"client_id" => "unknown"})
      {:error, %{error: :invalid_client, ...}, 401}
  """
  @spec deny(struct(), map()) ::
          {:redirect, binary()} | {:error, map(), integer() | atom()}
  def deny(resource_owner, params) do
    ExOauth2Provider.Authorization.deny(resource_owner, params, otp_app: @otp_app)
  end
end
