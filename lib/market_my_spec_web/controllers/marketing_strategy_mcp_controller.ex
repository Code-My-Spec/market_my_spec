defmodule MarketMySpecWeb.MarketingStrategyMcpController do
  @moduledoc """
  MCP server endpoint mounting `MarketMySpec.McpServers.MarketingStrategyServer`
  at `/mcp/marketing-strategy`.

  Bearer-token auth runs in the `:mcp_authenticated` pipeline. Delegates to the
  Anubis StreamableHTTP plug (JSON-RPC over POST, SSE over GET). Namespaced so
  the marketing-strategy topic stays separate from engagement and files.
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
