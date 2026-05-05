defmodule MarketMySpecSpex.Story683.Criterion5852Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5852 — An adjacent admin or debug tool fails the surface audit.
  This audit watches for tool-surface drift over time.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing

  @allowed_tools MapSet.new(~w(
    read_file write_file edit_file delete_file list_files
    invoke_skill list_skills load_step
  ))

  spex "tool surface audit rejects unrecognized tools" do
    scenario "any tool name not on the allowlist is reported" do
      when_ "the agent fetches the tool catalog", context do
        tools = Marketing.tools()
        names = MapSet.new(tools, fn t -> Map.get(t, :name) || Map.get(t, "name") end)
        {:ok, Map.put(context, :names, names)}
      end

      then_ "no name outside the allowlist appears", context do
        unexpected = MapSet.difference(context.names, @allowed_tools)

        assert MapSet.size(unexpected) == 0,
               "Unexpected tools in MCP surface: #{inspect(MapSet.to_list(unexpected))}"

        {:ok, context}
      end
    end
  end
end
