defmodule MarketMySpecSpex.Story710.Criterion6227Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6227 — Sam creates a search scoped to two specific Reddit subreddits.

  Sam creates a saved search whose recipe references two existing Reddit Venue
  records on his account (many-to-many via SavedSearchVenue). The search is
  persisted and the linked venues are reachable through the preloaded
  `:venues` association.

  Interaction surface: Engagements.SavedSearchesRepository.create_saved_search/2
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "Sam creates a search scoped to two specific Reddit subreddits" do
    scenario "create_saved_search succeeds with venue_ids referencing two Reddit venues" do
      given_ "Sam has two Reddit venues (r/elixir and r/programming) on his account",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        elixir_venue =
          Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        programming_venue =
          Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming"})

        {:ok,
         Map.merge(context, %{
           scope: scope,
           venue_ids: [elixir_venue.id, programming_venue.id]
         })}
      end

      when_ "Sam creates a SavedSearch named \"elixir hiring\" linked to both venues",
            context do
        result =
          SavedSearchesRepository.create_saved_search(context.scope, %{
            name: "elixir hiring",
            query: "elixir hiring",
            venue_ids: context.venue_ids
          })

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the SavedSearch is persisted with both venues linked", context do
        assert {:ok, saved_search} = context.result

        assert saved_search.name == "elixir hiring"
        assert saved_search.query == "elixir hiring"
        assert length(saved_search.venues) == 2

        linked_ids = Enum.map(saved_search.venues, & &1.id) |> Enum.sort()
        assert linked_ids == Enum.sort(context.venue_ids)

        {:ok, context}
      end
    end
  end
end
