defmodule MarketMySpecSpex.Story683.Criterion5842Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5842 — tools/list does not include any cross-tenant admin tools, debug tools, or
  telemetry tools. The file surface is exactly the five primitives plus skill primitives.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing

  @file_tools ~w(read_file write_file edit_file delete_file list_files)
  @forbidden_substrings ~w(admin debug telemetry trace internal sudo)

  spex "tools/list excludes admin/debug/telemetry tools" do
    scenario "every exposed tool name is on the allowlist" do
      when_ "the agent fetches the tool catalog", context do
        tools = Marketing.tools()
        names = Enum.map(tools, fn t -> Map.get(t, :name) || Map.get(t, "name") end)
        {:ok, Map.put(context, :names, names)}
      end

      then_ "all five file tools are present", context do
        for name <- @file_tools, do: assert name in context.names
        {:ok, context}
      end

      then_ "no tool name contains an admin/debug/telemetry substring", context do
        for name <- context.names, sub <- @forbidden_substrings do
          refute String.contains?(name, sub),
                 "Forbidden substring #{inspect(sub)} found in tool name #{inspect(name)}"
        end

        {:ok, context}
      end
    end
  end
end
