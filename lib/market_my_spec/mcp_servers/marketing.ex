defmodule MarketMySpec.McpServers.Marketing do
  @moduledoc """
  Public facade for the generic file-operations tool surface (the
  `MarketMySpec.McpServers.Marketing.Tools.*` primitives).

  Exposes `tools/0` so spex files (and any future introspection callers)
  can enumerate the registered tools without depending on Anubis internals.

  The file tools now live on `MarketMySpec.McpServers.FilesServer` (their own
  `/mcp/files` topic; they are also aggregated on the base `/mcp`
  `AllToolsServer`). This facade reads that server and filters to the auditable
  file-primitive surface, so it stays free of admin/debug/telemetry tools.

  Each element in the returned list is an `Anubis.Server.Component.Tool` struct
  with `:name`, `:description`, and `:input_schema` fields.
  """

  alias MarketMySpec.McpServers.FilesServer

  @file_tools ~w(read_file write_file edit_file delete_file list_files)
  @allowed_tool_names MapSet.new(@file_tools)

  @doc """
  Returns the file-primitive tool definitions, filtered to the auditable
  surface.
  """
  @spec tools() :: [Anubis.Server.Component.Tool.t()]
  def tools do
    FilesServer.__components__(:tool)
    |> Enum.filter(fn tool -> MapSet.member?(@allowed_tool_names, tool.name) end)
  end
end
