defmodule MarketMySpecWeb.Plugs.RequireMcpToken do
  @moduledoc """
  Plug that authenticates MCP requests using OAuth bearer tokens.

  Extracts the `Authorization: Bearer <token>` header and validates it
  against the McpAuth context. On success, assigns `:mcp_access_token` to
  the conn. On failure, halts with a 401 and a `WWW-Authenticate` header
  pointing to the protected-resource metadata endpoint.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias MarketMySpec.McpAuth.Token
  alias MarketMySpec.Users.Scope

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when token != "" ->
        authenticate(conn, token)

      _ ->
        unauthorized(conn)
    end
  end

  defp authenticate(conn, token) do
    case Token.authenticate(token) do
      {:ok, access_token} ->
        scope = Scope.for_user(access_token.resource_owner)

        conn
        |> assign(:mcp_access_token, access_token)
        |> assign(:current_scope, scope)

      {:error, _reason} ->
        unauthorized(conn)
    end
  end

  defp unauthorized(conn) do
    base_url = MarketMySpecWeb.Endpoint.url()
    resource_metadata_url = "#{base_url}/.well-known/oauth-protected-resource"

    conn
    |> put_resp_header(
      "www-authenticate",
      ~s(Bearer resource_metadata="#{resource_metadata_url}")
    )
    |> put_status(401)
    |> json(%{error: "unauthorized"})
    |> halt()
  end
end
