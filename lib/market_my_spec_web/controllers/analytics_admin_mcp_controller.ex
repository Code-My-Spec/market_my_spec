defmodule MarketMySpecWeb.AnalyticsAdminMcpController do
  @moduledoc """
  MCP server endpoint mounting `MarketMySpec.McpServers.AnalyticsAdminServer`.

  Bearer-token authentication runs in the `:mcp_authenticated` pipeline
  (`MarketMySpecWeb.Plugs.RequireMcpToken`); by the time `handle/2` is
  invoked, the conn already carries `:current_scope` and
  `:mcp_access_token`.

  Delegates to `Anubis.Server.Transport.StreamableHTTP.Plug`, which
  handles JSON-RPC over POST and the long-lived SSE stream over GET,
  plus session lifecycle. Configured separately from `McpController`
  so the marketing-strategy and analytics-admin tool surfaces stay on
  independently namespaced endpoints.
  """

  use MarketMySpecWeb, :controller

  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug

  @anubis_opts AnubisPlug.init(
                 server: MarketMySpec.McpServers.AnalyticsAdminServer
               )

  @spec handle(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def handle(conn, _params) do
    AnubisPlug.call(conn, @anubis_opts)
  end
end
