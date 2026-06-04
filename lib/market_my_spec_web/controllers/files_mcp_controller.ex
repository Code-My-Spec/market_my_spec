defmodule MarketMySpecWeb.FilesMcpController do
  @moduledoc """
  MCP server endpoint mounting `MarketMySpec.McpServers.FilesServer` at
  `/mcp/files` — generic account file operations.

  Bearer-token auth runs in the `:mcp_authenticated` pipeline. Delegates to the
  Anubis StreamableHTTP plug (JSON-RPC over POST, SSE over GET).
  """

  use MarketMySpecWeb, :controller

  alias Anubis.Server.Transport.StreamableHTTP.Plug, as: AnubisPlug

  @anubis_opts AnubisPlug.init(
                 server: MarketMySpec.McpServers.FilesServer
               )

  @spec handle(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def handle(conn, _params) do
    AnubisPlug.call(conn, @anubis_opts)
  end
end
