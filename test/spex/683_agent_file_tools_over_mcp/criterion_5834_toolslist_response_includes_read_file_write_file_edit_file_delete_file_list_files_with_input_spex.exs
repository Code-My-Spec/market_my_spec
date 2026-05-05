defmodule MarketMySpecSpex.Story683.Criterion5834Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5834 — tools/list response includes read_file, write_file, edit_file, delete_file, list_files
  with input schemas matching the Claude Code shape.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing

  spex "tools/list exposes the five Claude-Code-shaped file tools" do
    scenario "the marketing MCP server's tool catalog matches the Claude Code shape" do
      when_ "the agent fetches the tool list from the marketing MCP server", context do
        tools = Marketing.tools()
        {:ok, Map.put(context, :tools, tools)}
      end

      then_ "read_file is present with {path} input", context do
        tool = find_tool(context.tools, "read_file")
        assert required(tool) == ["path"]
        {:ok, context}
      end

      then_ "write_file is present with {path, content} input", context do
        tool = find_tool(context.tools, "write_file")
        assert MapSet.new(required(tool)) == MapSet.new(["path", "content"])
        {:ok, context}
      end

      then_ "edit_file is present with {path, old_string, new_string} input and optional replace_all", context do
        tool = find_tool(context.tools, "edit_file")
        assert MapSet.new(required(tool)) == MapSet.new(["path", "old_string", "new_string"])
        assert "replace_all" in Map.keys(properties(tool))
        {:ok, context}
      end

      then_ "delete_file is present with {path} input", context do
        tool = find_tool(context.tools, "delete_file")
        assert required(tool) == ["path"]
        {:ok, context}
      end

      then_ "list_files is present with optional prefix", context do
        tool = find_tool(context.tools, "list_files")
        assert "prefix" in Map.keys(properties(tool))
        refute "prefix" in (required(tool) || [])
        {:ok, context}
      end
    end
  end

  defp find_tool(tools, name) do
    Enum.find(tools, fn t -> Map.get(t, :name) == name or Map.get(t, "name") == name end) ||
      flunk("Tool #{name} not found in tools/list")
  end

  defp required(tool) do
    schema = Map.get(tool, :input_schema) || Map.get(tool, "input_schema") || %{}
    Map.get(schema, :required) || Map.get(schema, "required") || []
  end

  defp properties(tool) do
    schema = Map.get(tool, :input_schema) || Map.get(tool, "input_schema") || %{}
    Map.get(schema, :properties) || Map.get(schema, "properties") || %{}
  end
end
