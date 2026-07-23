defmodule MarketMySpecSpex.Story710.Criterion6228Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6228 — Sam creates a search scoped to "all ElixirForum".

  Sam creates a saved search using only the ElixirForum source wildcard, with
  no explicit venue ids. The search is persisted with the wildcard recorded
  in `source_wildcards` and zero linked venues.

  Interaction surface: Engagements.SavedSearchesRepository.create_saved_search/2
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "Sam creates a search scoped to all ElixirForum" do
    scenario "create_saved_search succeeds with only source_wildcards: [:elixirforum]" do
      given_ "Sam has an account with at least one enabled ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()

        _venue =
          Fixtures.venue_fixture(scope, %{source: :elixirforum, identifier: "10"})

        {:ok, Map.put(context, :scope, scope)}
      end

      when_ "Sam creates a SavedSearch with only the elixirforum source wildcard",
            context do
        result =
          SavedSearchesRepository.create_saved_search(context.scope, %{
            name: "elixir testing",
            query: "elixir testing",
            source_wildcards: [:elixirforum]
          })

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the SavedSearch is persisted with the wildcard and no explicit venues",
            context do
        assert {:ok, saved_search} = context.result
        assert saved_search.name == "elixir testing"
        assert saved_search.source_wildcards == [:elixirforum]
        assert saved_search.venues == []

        {:ok, context}
      end
    end
  end
end
