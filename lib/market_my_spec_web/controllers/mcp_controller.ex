defmodule MarketMySpecWeb.McpController do
  @moduledoc """
  MCP server endpoint mounting Anubis MCP.

  Bearer-token authentication runs in the `:mcp_authenticated` pipeline
  (`MarketMySpecWeb.Plugs.RequireMcpToken`); by the time `handle/2` is
  invoked, the conn already carries `:mcp_access_token`.

  This controller delegates the request to
  `Anubis.Server.Transport.StreamableHTTP.Plug`, configured to serve the
  `MarketMySpec.McpServers.MarketingStrategyServer`. The Anubis transport
  handles JSON-RPC over POST and the long-lived SSE stream over GET, plus
  session lifecycle.
  """

  use MarketMySpecWeb, :controller

  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug

  @anubis_opts AnubisPlug.init(
                 server: MarketMySpec.McpServers.MarketingStrategyServer
               )

  @spec handle(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def handle(conn, _params) do
    AnubisPlug.call(conn, @anubis_opts)
  end
end
