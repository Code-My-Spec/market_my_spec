defmodule MarketMySpec.McpAuth do
  @moduledoc """
  OAuth 2.0 authorization server boundary for MCP clients.

  Delegates token grant/revoke/authentication, authorization-code flow, and
  connection-info to the three focused sub-modules:

  - `MarketMySpec.McpAuth.Token` — bearer token grant, revocation, and validation
  - `MarketMySpec.McpAuth.Authorization` — PKCE auth-code flow (preauthorize/authorize/deny)
  - `MarketMySpec.McpAuth.ConnectionInfo` — server URL, install command, setup guide

  Well-known OAuth metadata (RFC 9728 / RFC 8414) is built at request time by
  `MarketMySpecWeb.OauthController` using `MarketMySpecWeb.Endpoint.url()` so
  the issuer and resource URLs reflect the correct runtime host.

  This module is the single public surface for the MCP OAuth context. Callers
  (controllers, plugs, LiveViews) import only this module rather than reaching
  into sub-modules directly.
  """

  alias MarketMySpec.McpAuth.{Authorization, ConnectionInfo, Token}
  alias MarketMySpec.Oauth.Application, as: OauthApplication
  alias MarketMySpec.Repo

  # ---------------------------------------------------------------------------
  # Token
  # ---------------------------------------------------------------------------

  @doc """
  Grants an access token based on the grant_type in the request params.

  Delegates to `MarketMySpec.McpAuth.Token.grant/1`.
  """
  @spec grant(map()) :: {:ok, struct()} | {:error, map(), integer() | atom()}
  defdelegate grant(params), to: Token

  @doc """
  Revokes an access token per RFC 7009.

  Delegates to `MarketMySpec.McpAuth.Token.revoke/1`.
  """
  @spec revoke(map()) :: {:ok, struct()} | {:error, map(), integer() | atom()}
  defdelegate revoke(params), to: Token

  @doc """
  Authenticates a bearer token extracted from an MCP request.

  Delegates to `MarketMySpec.McpAuth.Token.authenticate/1`.
  """
  @spec authenticate(binary() | nil) :: {:ok, struct()} | {:error, atom()}
  defdelegate authenticate(token), to: Token

  # ---------------------------------------------------------------------------
  # Authorization
  # ---------------------------------------------------------------------------

  @doc """
  Pre-authorizes an OAuth request, returning the client and requested scopes
  for rendering a consent screen.

  Delegates to `MarketMySpec.McpAuth.Authorization.preauthorize/2`.
  """
  @spec preauthorize(struct(), map()) ::
          {:ok, struct(), list()}
          | {:redirect, binary()}
          | {:native_redirect, map()}
          | {:error, map(), integer() | atom()}
  defdelegate preauthorize(resource_owner, params), to: Authorization

  @doc """
  Authorizes an OAuth request after the user grants consent, issuing an
  authorization code via redirect.

  Delegates to `MarketMySpec.McpAuth.Authorization.authorize/2`.
  """
  @spec authorize(struct(), map()) ::
          {:redirect, binary()}
          | {:native_redirect, map()}
          | {:error, map(), integer() | atom()}
  defdelegate authorize(resource_owner, params), to: Authorization

  @doc """
  Denies an OAuth request, redirecting back to the client with an
  access_denied error.

  Delegates to `MarketMySpec.McpAuth.Authorization.deny/2`.
  """
  @spec deny(struct(), map()) ::
          {:redirect, binary()} | {:error, map(), integer() | atom()}
  defdelegate deny(resource_owner, params), to: Authorization

  # ---------------------------------------------------------------------------
  # ConnectionInfo
  # ---------------------------------------------------------------------------

  @doc """
  Returns the MCP server URL.

  Delegates to `MarketMySpec.McpAuth.ConnectionInfo.server_url/0`.
  """
  @spec server_url() :: String.t()
  defdelegate server_url(), to: ConnectionInfo

  @doc """
  Returns the Claude Code CLI command to install this server as an MCP plugin.

  Delegates to `MarketMySpec.McpAuth.ConnectionInfo.install_command/0`.
  """
  @spec install_command() :: String.t()
  defdelegate install_command(), to: ConnectionInfo

  @doc """
  Returns the setup-guide payload consumed by McpSetupLive.

  Delegates to `MarketMySpec.McpAuth.ConnectionInfo.setup_info/0`.
  """
  @spec setup_info() :: ConnectionInfo.connection_info()
  defdelegate setup_info(), to: ConnectionInfo

  # ---------------------------------------------------------------------------
  # Dynamic Client Registration
  # ---------------------------------------------------------------------------

  @doc """
  Registers a new OAuth application (dynamic client registration).

  Creates an `OauthApplication` record with the given attributes. Returns
  `{:ok, application}` on success or `{:error, changeset}` on validation
  failure.

  ## Examples

      iex> register_application(%{name: "MCP Client", redirect_uri: "http://localhost:3000/callback", scopes: "read write", uid: "mcp_abc123", secret: "s3cr3t"})
      {:ok, %MarketMySpec.Oauth.Application{}}

      iex> register_application(%{})
      {:error, %Ecto.Changeset{}}

  """
  @spec register_application(map()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def register_application(attrs) do
    %OauthApplication{}
    |> OauthApplication.changeset(attrs)
    |> Repo.insert()
  end
end
