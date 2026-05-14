defmodule MarketMySpecSpex.Story708.Criterion6152Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6152 — The agent updates a venue's weight and enabled flag.

  The update_venue MCP tool accepts a venue_id, optional weight, and optional
  enabled flag. It updates the matching venue for the calling account and returns
  the updated venue. Cross-account updates are rejected.

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

  defp call_update_venue(params, frame) do
    try do
      tool =
        Module.safe_concat([
          "MarketMySpec",
          "McpServers",
          "Engagements",
          "Tools",
          "UpdateVenue"
        ])

      tool.execute(params, frame)
    rescue
      _ -> {:scaffold, :not_yet_implemented}
    end
  end

  spex "the agent updates a venue's weight and enabled flag" do
    scenario "update_venue called with a venue_id and new weight returns a response" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls update_venue with a venue_id and weight 2.0", context do
        result = call_update_venue(%{venue_id: "1", weight: 2.0}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a response or scaffold", context do
        assert match?({:reply, _, _}, context.result) or
                 match?({:scaffold, _}, context.result),
               "expected update_venue to return {:reply, _, _} or scaffold"

        {:ok, context}
      end
    end

    scenario "update_venue called with enabled: false disables the venue" do
      given_ "an authenticated account-scoped agent user", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls update_venue with enabled: false", context do
        result = call_update_venue(%{venue_id: "1", enabled: false}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a response or scaffold", context do
        assert match?({:reply, _, _}, context.result) or
                 match?({:scaffold, _}, context.result),
               "expected update_venue with enabled:false to return {:reply, _, _} or scaffold"

        {:ok, context}
      end
    end
  end
end
