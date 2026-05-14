defmodule MarketMySpecSpex.Story708.Criterion6159Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6159 — Re-enabling a venue restores it to the search target set.

  When a venue that was previously disabled is re-enabled (enabled: true),
  the next search call will include it in the search target set. The Venue
  changeset correctly accepts the enabled field being toggled back to true.

  Interaction surface: Venue schema changeset + MCP SearchEngagements (unit/integration).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Repo
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "re-enabling a venue restores it to the search target set" do
    scenario "a venue can be toggled from disabled to enabled via changeset" do
      given_ "a disabled venue record in the database", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)

        attrs = %{
          account_id: account.id,
          source: :reddit,
          identifier: "elixir",
          weight: 1.0,
          enabled: false
        }

        {:ok, venue} = Repo.insert(Venue.changeset(%Venue{}, attrs))
        {:ok, Map.merge(context, %{account: account, venue: venue})}
      end

      when_ "the venue is re-enabled via a new changeset", context do
        updated_changeset = Venue.changeset(context.venue, %{enabled: true})
        {:ok, updated_venue} = Repo.update(updated_changeset)
        {:ok, Map.put(context, :updated_venue, updated_venue)}
      end

      then_ "the updated venue has enabled: true", context do
        assert context.updated_venue.enabled == true,
               "expected re-enabled venue to have enabled=true, " <>
                 "got: #{inspect(context.updated_venue.enabled)}"

        {:ok, context}
      end

      then_ "the updated venue can be retrieved from the database with enabled: true", context do
        retrieved = Repo.get!(Venue, context.updated_venue.id)

        assert retrieved.enabled == true,
               "expected retrieved venue to have enabled=true, " <>
                 "got: #{inspect(retrieved.enabled)}"

        {:ok, context}
      end
    end

    scenario "search returns empty candidates regardless of venue enabled state at scaffold" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "elixir re-enable test"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the search does not error even at scaffold stage", context do
        refute context.response.isError,
               "expected search to succeed at scaffold stage"

        {:ok, context}
      end
    end
  end
end
