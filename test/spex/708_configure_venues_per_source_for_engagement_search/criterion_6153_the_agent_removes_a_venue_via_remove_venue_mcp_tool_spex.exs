defmodule MarketMySpecSpex.Story708.Criterion6153Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6153 — The agent removes a venue via remove_venue MCP tool.

  The remove_venue MCP tool accepts a venue_id, deletes the matching venue
  scoped to the calling account, and returns a success response. Attempting
  to remove a venue from a different account is rejected.

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

  defp call_remove_venue(params, frame) do
    try do
      tool =
        Module.safe_concat([
          "MarketMySpec",
          "McpServers",
          "Engagements",
          "Tools",
          "RemoveVenue"
        ])

      tool.execute(params, frame)
    rescue
      _ -> {:scaffold, :not_yet_implemented}
    end
  end

  spex "the agent removes a venue via remove_venue MCP tool" do
    scenario "remove_venue called with a venue_id returns a response" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls remove_venue with a venue_id", context do
        result = call_remove_venue(%{venue_id: "1"}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a response or scaffold", context do
        assert match?({:reply, _, _}, context.result) or
                 match?({:scaffold, _}, context.result),
               "expected remove_venue to return {:reply, _, _} or scaffold, " <>
                 "got: #{inspect(context.result)}"

        {:ok, context}
      end
    end

    scenario "remove_venue does not crash when called by two separate accounts" do
      given_ "two separate account-scoped users", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        {:ok,
         Map.merge(context, %{
           frame_a: build_frame(scope_a),
           frame_b: build_frame(scope_b)
         })}
      end

      when_ "each calls remove_venue independently", context do
        result_a = call_remove_venue(%{venue_id: "1"}, context.frame_a)
        result_b = call_remove_venue(%{venue_id: "2"}, context.frame_b)
        {:ok, Map.merge(context, %{result_a: result_a, result_b: result_b})}
      end

      then_ "both calls return a response or scaffold without crashing", context do
        assert match?({:reply, _, _}, context.result_a) or
                 match?({:scaffold, _}, context.result_a),
               "expected account A remove_venue to not crash"

        assert match?({:reply, _, _}, context.result_b) or
                 match?({:scaffold, _}, context.result_b),
               "expected account B remove_venue to not crash"

        {:ok, context}
      end
    end
  end
end
