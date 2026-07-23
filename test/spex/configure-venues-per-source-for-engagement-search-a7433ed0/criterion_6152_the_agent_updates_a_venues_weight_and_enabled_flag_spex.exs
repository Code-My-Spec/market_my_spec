defmodule MarketMySpecSpex.Story708.Criterion6152Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6152 — The agent updates a venue's weight and enabled flag.

  The update_venue MCP tool accepts a venue_id, optional weight, and optional
  enabled flag. The matching venue for the calling account is updated and the
  new state is reflected both in the response payload and the database.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
  alias MarketMySpec.McpServers.Engagements.Tools.UpdateVenue
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  spex "the agent updates a venue's weight and enabled flag" do
    scenario "update_venue raises a venue's weight" do
      given_ "an account with a venue at weight 1.0", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", weight: 1.0})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope), venue: venue})}
      end

      when_ "the agent calls update_venue with weight: 2.0", context do
        result =
          UpdateVenue.execute(
            %{venue_id: context.venue.id, weight: 2.0},
            context.frame
          )

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response is a reply tuple and the venue's weight is now 2.0", context do
        assert {:reply, %Response{}, _frame} = context.result

        [updated] =
          Engagements.list_venues(context.scope, :reddit)
          |> Enum.filter(&(&1.id == context.venue.id))

        assert updated.weight == 2.0

        {:ok, context}
      end
    end

    scenario "update_venue disables a venue" do
      given_ "an account with an enabled venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope), venue: venue})}
      end

      when_ "the agent calls update_venue with enabled: false", context do
        result =
          UpdateVenue.execute(
            %{venue_id: context.venue.id, enabled: false},
            context.frame
          )

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response is a reply tuple and the venue is now disabled", context do
        assert {:reply, %Response{}, _frame} = context.result

        [updated] =
          Engagements.list_venues(context.scope, :reddit)
          |> Enum.filter(&(&1.id == context.venue.id))

        refute updated.enabled, "expected venue to be disabled after update_venue"

        {:ok, context}
      end
    end
  end
end
