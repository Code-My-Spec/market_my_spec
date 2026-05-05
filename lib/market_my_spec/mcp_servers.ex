defmodule MarketMySpec.McpServers do
  @moduledoc """
  MCP (Model Context Protocol) servers context.

  Provides the namespace for MCP server implementations.
  The actual MCP protocol handling is delegated to Anubis.Server.

  Declared as its own Boundary so other top-level boundaries
  (MarketMySpecWeb, etc.) can depend on the agent surface without
  pulling in all of MarketMySpec.
  """
  use Boundary, deps: [MarketMySpec, MarketMySpec.Repo], exports: :all
end
