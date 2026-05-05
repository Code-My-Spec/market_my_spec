defmodule MarketMySpec.McpServers.Marketing do
  @moduledoc """
  Public facade for the marketing-strategy MCP server's tool surface.

  Exposes `tools/0` so spex files (and any future introspection callers)
  can enumerate the registered tools without depending on Anubis internals.

  Returns only the file-primitive tools and skill-primitive tools. Skill tools
  (`start_interview`, internal tools) are intentionally excluded to keep this
  surface auditable and free of admin/debug tools.

  Each element in the returned list is an `Anubis.Server.Component.Tool` struct
  with `:name`, `:description`, and `:input_schema` fields.
  """

  alias MarketMySpec.McpServers.MarketingStrategyServer

  @file_tools ~w(read_file write_file edit_file delete_file list_files)
  @skill_tools ~w(invoke_skill list_skills load_step)
  @allowed_tool_names MapSet.new(@file_tools ++ @skill_tools)

  @doc """
  Returns the list of tool definitions on the marketing-strategy MCP server,
  filtered to the auditable file-primitive and skill-primitive surface.
  """
  @spec tools() :: [Anubis.Server.Component.Tool.t()]
  def tools do
    MarketingStrategyServer.__components__(:tool)
    |> Enum.filter(fn tool -> MapSet.member?(@allowed_tool_names, tool.name) end)
  end
end
