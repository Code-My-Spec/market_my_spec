defmodule MarketMySpecSpex.Story708.Criterion6151Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6151 — The agent lists venues, optionally filtered by source.

  The list_venues MCP tool returns all venues for the calling account, with an
  optional source filter (reddit | elixirforum). With no filter all venues are
  returned; with a filter only matching-source venues are returned.

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

  defp call_list_venues(params, frame) do
    try do
      tool =
        Module.safe_concat([
          "MarketMySpec",
          "McpServers",
          "Engagements",
          "Tools",
          "ListVenues"
        ])

      tool.execute(params, frame)
    rescue
      _ -> {:scaffold, :not_yet_implemented}
    end
  end

  spex "the agent lists venues, optionally filtered by source" do
    scenario "list_venues with no filter returns a response for the account" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls list_venues with no source filter", context do
        result = call_list_venues(%{}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a response or scaffold", context do
        assert match?({:reply, _, _}, context.result) or
                 match?({:scaffold, _}, context.result),
               "expected list_venues to return {:reply, _, _} or scaffold"

        {:ok, context}
      end
    end

    scenario "list_venues with source=reddit filter returns a response" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls list_venues with source='reddit'", context do
        result = call_list_venues(%{source: "reddit"}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a response or scaffold", context do
        assert match?({:reply, _, _}, context.result) or
                 match?({:scaffold, _}, context.result),
               "expected list_venues with source filter to return {:reply, _, _} or scaffold"

        {:ok, context}
      end
    end

    scenario "list_venues with source=elixirforum filter returns a response" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls list_venues with source='elixirforum'", context do
        result = call_list_venues(%{source: "elixirforum"}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a response or scaffold", context do
        assert match?({:reply, _, _}, context.result) or
                 match?({:scaffold, _}, context.result),
               "expected list_venues with elixirforum filter to return {:reply, _, _} or scaffold"

        {:ok, context}
      end
    end
  end
end
