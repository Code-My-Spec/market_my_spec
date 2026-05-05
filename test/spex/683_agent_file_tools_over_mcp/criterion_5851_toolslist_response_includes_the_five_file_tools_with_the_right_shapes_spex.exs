defmodule MarketMySpecSpex.Story683.Criterion5851Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5851 — tools/list response includes the five file tools with the right shapes.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing

  spex "tools/list shape audit for the five file tools" do
    scenario "each file tool exposes a Claude-Code-shaped JSON schema" do
      when_ "the agent fetches the tool catalog", context do
        tools = Marketing.tools()
        {:ok, Map.put(context, :tools, tools)}
      end

      then_ "every required file tool has a name and an input schema", context do
        for name <- ~w(read_file write_file edit_file delete_file list_files) do
          tool = Enum.find(context.tools, fn t -> tool_name(t) == name end)
          assert tool, "Missing tool: #{name}"
          assert input_schema(tool), "Tool #{name} missing input_schema"
        end

        {:ok, context}
      end
    end
  end

  defp tool_name(t), do: Map.get(t, :name) || Map.get(t, "name")
  defp input_schema(t), do: Map.get(t, :input_schema) || Map.get(t, "input_schema")
end
