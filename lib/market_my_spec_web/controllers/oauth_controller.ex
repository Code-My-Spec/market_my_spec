defmodule MarketMySpecWeb.OauthController do
  @moduledoc """
  OAuth2 Authorization Server Controller.

  Handles OAuth2 token endpoint, revocation, dynamic client registration,
  and well-known metadata endpoints for MCP clients.

  The authorization consent UI is handled by McpAuthorizationLive.
  """

  use MarketMySpecWeb, :controller

  alias MarketMySpec.McpAuth

  @mcp_path "/mcp"
  @authorize_path "/oauth/authorize"
  @token_path "/oauth/token"
  @register_path "/oauth/register"
  @revoke_path "/oauth/revoke"
  @scopes_supported ["read", "write"]
  @response_types_supported ["code"]
  @grant_types_supported ["authorization_code", "client_credentials"]
  @code_challenge_methods_supported ["S256"]
  @token_endpoint_auth_methods_supported ["client_secret_post", "none"]
  @bearer_methods_supported ["header"]

  # Syntactically valid token characters per RFC 6750: printable ASCII excluding space
  # Token = 1*VSCHAR where VSCHAR = %x21-7E
  @valid_token_pattern ~r/\A[\x21-\x7E]+\z/

  @doc """
  GET /.well-known/oauth-protected-resource
  MCP Protected Resource Metadata (RFC 9728)

  Builds metadata at request time using the endpoint URL so that the
  `resource` and `authorization_servers` fields reflect the actual runtime
  host, not a hard-coded config value.
  """
  @spec protected_resource_metadata(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def protected_resource_metadata(conn, _params) do
    base = get_base_url()

    metadata = %{
      "resource" => base <> @mcp_path,
      "authorization_servers" => [base],
      "scopes_supported" => @scopes_supported,
      "bearer_methods_supported" => @bearer_methods_supported
    }

    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(metadata)
  end

  @doc """
  GET /.well-known/oauth-authorization-server
  Authorization Server Metadata (RFC 8414)

  Builds metadata at request time using the endpoint URL so that the
  `issuer` and all endpoint fields reflect the actual runtime host.
  """
  @spec authorization_server_metadata(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def authorization_server_metadata(conn, _params) do
    base = get_base_url()

    metadata = %{
      "issuer" => base,
      "authorization_endpoint" => base <> @authorize_path,
      "token_endpoint" => base <> @token_path,
      "registration_endpoint" => base <> @register_path,
      "scopes_supported" => @scopes_supported,
      "response_types_supported" => @response_types_supported,
      "grant_types_supported" => @grant_types_supported,
      "code_challenge_methods_supported" => @code_challenge_methods_supported,
      "token_endpoint_auth_methods_supported" => @token_endpoint_auth_methods_supported,
      "revocation_endpoint" => base <> @revoke_path
    }

    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(metadata)
  end

  @doc """
  POST /oauth/register
  Dynamic Client Registration for MCP clients.

  Validates that `redirect_uris` is present and non-empty before attempting
  to persist the application. Returns 400 with `invalid_client_metadata` if
  the field is missing or empty.
  """
  @spec register(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def register(conn, params) do
    redirect_uris = params["redirect_uris"] || []

    if redirect_uris == [] or (is_list(redirect_uris) and Enum.all?(redirect_uris, &(&1 == ""))) do
      conn
      |> put_status(400)
      |> json(%{
        "error" => "invalid_client_metadata",
        "error_description" => "redirect_uris is required and must contain at least one URI"
      })
    else
      attrs = %{
        name: params["client_name"] || "MCP Client",
        redirect_uri: Enum.join(redirect_uris, " "),
        scopes: "read write",
        uid: generate_client_id(),
        secret: generate_client_secret()
      }

      case McpAuth.register_application(attrs) do
        {:ok, application} ->
          conn
          |> put_status(201)
          |> json(%{
            "client_id" => application.uid,
            "client_secret" => application.secret,
            "client_name" => application.name,
            "redirect_uris" => String.split(application.redirect_uri || "", " ", trim: true),
            "grant_types" => ["authorization_code"],
            "response_types" => ["code"],
            "scope" => application.scopes
          })

        {:error, changeset} ->
          conn
          |> put_status(400)
          |> json(%{
            "error" => "invalid_client_metadata",
            "error_description" => format_errors(changeset)
          })
      end
    end
  end

  @doc """
  POST /oauth/token
  Token endpoint — delegates to McpAuth.grant/1.

  ExOauth2Provider.Token.grant/2 returns {:ok, body_map} where body_map already
  contains the standard OAuth 2.0 token response fields (access_token, token_type,
  expires_in, refresh_token, scope) as atom keys. We pass this through directly,
  normalizing the token_type to "Bearer" for RFC 6750 compliance.
  """
  @spec token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def token(conn, params) do
    case McpAuth.grant(params) do
      {:ok, token_body} ->
        # ExOauth2Provider returns a map with atom keys: access_token, token_type,
        # expires_in, refresh_token, scope, created_at
        json(conn, %{
          "access_token" => token_body.access_token,
          "refresh_token" => token_body.refresh_token,
          "expires_in" => token_body.expires_in,
          "token_type" => "Bearer",
          "scope" => token_body.scope
        })

      {:error, error, http_status} ->
        conn
        |> put_status(http_status)
        |> json(%{"error" => "invalid_request", "error_description" => inspect(error)})
    end
  end

  @doc """
  POST /oauth/revoke
  Token revocation per RFC 7009 — delegates to McpAuth.revoke/1.

  A syntactically invalid token (containing characters outside the printable
  ASCII range %x21-7E, or containing spaces) is rejected with 400
  `invalid_request` before any database lookup.
  """
  @spec revoke(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def revoke(conn, params) do
    token = params["token"]

    cond do
      is_nil(token) or token == "" ->
        conn
        |> put_status(400)
        |> json(%{"error" => "invalid_request", "error_description" => "token parameter is required"})

      not Regex.match?(@valid_token_pattern, token) ->
        conn
        |> put_status(400)
        |> json(%{"error" => "invalid_request", "error_description" => "token contains invalid characters"})

      true ->
        case McpAuth.revoke(params) do
          {:ok, _} ->
            conn
            |> put_status(:ok)
            |> json(%{})

          {:error, error, http_status} ->
            conn
            |> put_status(http_status)
            |> json(%{"error" => "invalid_request", "error_description" => inspect(error)})
        end
    end
  end

  defp get_base_url do
    MarketMySpecWeb.Endpoint.url()
  end

  defp generate_client_id do
    "mcp_" <> (:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false))
  end

  defp generate_client_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end
end
