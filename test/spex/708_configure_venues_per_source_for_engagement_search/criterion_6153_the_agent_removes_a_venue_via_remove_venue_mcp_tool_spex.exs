defmodule MarketMySpecSpex.Story708.Criterion6153Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6153 — The agent removes a venue via remove_venue MCP tool.

  The remove_venue MCP tool deletes the matching venue scoped to the calling
  account. After the call, the venue is gone from list_venues. Cross-account
  removes return an error response and never delete the other account's row.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
  alias MarketMySpec.McpServers.Engagements.Tools.RemoveVenue
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  spex "the agent removes a venue via remove_venue MCP tool" do
    scenario "remove_venue deletes the venue from the calling account" do
      given_ "an account with one venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope), venue: venue})}
      end

      when_ "the agent calls remove_venue with the venue id", context do
        result = RemoveVenue.execute(%{venue_id: context.venue.id}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the call returns a reply tuple and the venue is gone from list_venues",
            context do
        assert {:reply, %Response{}, _frame} = context.result

        remaining = Engagements.list_venues(context.scope)
        refute Enum.any?(remaining, &(&1.id == context.venue.id)),
               "expected venue #{context.venue.id} to be removed"

        {:ok, context}
      end
    end

    scenario "remove_venue cannot delete a venue belonging to a different account" do
      given_ "two accounts, each with their own venue", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()
        venue_a = Fixtures.venue_fixture(scope_a, %{source: :reddit, identifier: "elixir"})
        venue_b = Fixtures.venue_fixture(scope_b, %{source: :reddit, identifier: "phoenix"})

        {:ok,
         Map.merge(context, %{
           scope_a: scope_a,
           scope_b: scope_b,
           frame_b: build_frame(scope_b),
           venue_a: venue_a,
           venue_b: venue_b
         })}
      end

      when_ "account B's frame calls remove_venue against account A's venue", context do
        result = RemoveVenue.execute(%{venue_id: context.venue_a.id}, context.frame_b)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response is a reply tuple and account A's venue still exists", context do
        assert {:reply, %Response{}, _frame} = context.result

        a_venues = Engagements.list_venues(context.scope_a)
        assert Enum.any?(a_venues, &(&1.id == context.venue_a.id)),
               "expected account A's venue to be untouched by account B's remove_venue call"

        {:ok, context}
      end
    end
  end
end
