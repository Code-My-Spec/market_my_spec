defmodule MarketMySpec.McpServers.FilesServer do
  @moduledoc """
  Anubis MCP server for generic account file operations — list, read, write,
  edit, delete. Mounted at `/mcp/files`.

  A standalone topic so any client can mount just the workspace file tools. The
  base `/mcp` (`MarketMySpec.McpServers.AllToolsServer`) also exposes these.
  """

  use Anubis.Server,
    name: "files",
    version: "1.0.0",
    capabilities: [:tools]

  component(MarketMySpec.McpServers.Marketing.Tools.ListFiles)
  component(MarketMySpec.McpServers.Marketing.Tools.ReadFile)
  component(MarketMySpec.McpServers.Marketing.Tools.WriteFile)
  component(MarketMySpec.McpServers.Marketing.Tools.EditFile)
  component(MarketMySpec.McpServers.Marketing.Tools.DeleteFile)
end
