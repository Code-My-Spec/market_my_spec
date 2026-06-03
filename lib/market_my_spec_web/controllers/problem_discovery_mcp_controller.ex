defmodule MarketMySpecWeb.ProblemDiscoveryMcpController do
  @moduledoc """
  MCP server endpoint mounting `MarketMySpec.McpServers.ProblemDiscoveryServer`.

  Bearer-token authentication runs in the `:mcp_authenticated` pipeline
  (`MarketMySpecWeb.Plugs.RequireMcpToken`); by the time `handle/2` is
  invoked, the conn already carries `:current_scope` and
  `:mcp_access_token`.

  Delegates to `Anubis.Server.Transport.StreamableHTTP.Plug` for the
  JSON-RPC + SSE transport. Configured separately from `McpController`
  (marketing-strategy) and `AnalyticsAdminMcpController` so the
  problem-discovery tool surface lives on its own endpoint.
  """

  use MarketMySpecWeb, :controller

  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug

  @anubis_opts AnubisPlug.init(server: MarketMySpec.McpServers.ProblemDiscoveryServer)

  @spec handle(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def handle(conn, _params) do
    AnubisPlug.call(conn, @anubis_opts)
  end
end
