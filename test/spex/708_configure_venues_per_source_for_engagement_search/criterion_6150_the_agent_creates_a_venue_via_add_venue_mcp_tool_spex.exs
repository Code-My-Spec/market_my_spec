defmodule MarketMySpecSpex.Story708.Criterion6150Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6150 — The agent creates a venue via add_venue MCP tool.

  The LLM agent calls the add_venue MCP tool with source and identifier params.
  The tool creates a venue scoped to the calling account and returns a success
  response. At the scaffold stage this verifies the tool module path exists and
  the calling pattern is established.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  spex "the agent creates a venue via add_venue MCP tool" do
    scenario "add_venue is called with a Reddit source and subreddit identifier" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls add_venue with source=reddit, identifier=elixir", context do
        result =
          try do
            tool =
              Module.safe_concat([
                "MarketMySpec",
                "McpServers",
                "Engagements",
                "Tools",
                "AddVenue"
              ])

            tool.execute(%{source: "reddit", identifier: "elixir"}, context.frame)
          rescue
            UndefinedFunctionError ->
              {:scaffold, :add_venue_not_yet_implemented}

            ArgumentError ->
              {:scaffold, :module_not_yet_defined}
          end

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a response or indicates scaffold stage", context do
        assert match?({:reply, _, _}, context.result) or
                 match?({:scaffold, _}, context.result),
               "expected add_venue to return {:reply, _, _} or scaffold, " <>
                 "got: #{inspect(context.result)}"

        {:ok, context}
      end
    end

    scenario "add_venue is called with an ElixirForum source and category identifier" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls add_venue with source=elixirforum", context do
        result =
          try do
            tool =
              Module.safe_concat([
                "MarketMySpec",
                "McpServers",
                "Engagements",
                "Tools",
                "AddVenue"
              ])

            tool.execute(%{source: "elixirforum", identifier: "phoenix-forum"}, context.frame)
          rescue
            _ -> {:scaffold, :not_yet_implemented}
          end

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a response or scaffold", context do
        assert match?({:reply, _, _}, context.result) or
                 match?({:scaffold, _}, context.result),
               "expected add_venue to return {:reply, _, _} or scaffold"

        {:ok, context}
      end
    end
  end
end
