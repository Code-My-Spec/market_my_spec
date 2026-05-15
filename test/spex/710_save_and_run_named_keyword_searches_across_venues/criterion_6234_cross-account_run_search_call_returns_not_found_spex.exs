defmodule MarketMySpecSpex.Story710.Criterion6234Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6234 — Cross-account run_search call returns not_found.

  Account A owns a SavedSearch. A user signed in on Account B (no membership
  in A) attempts to run it via the repository function. The call returns
  `{:error, :not_found}` — no data leaks across accounts.

  Interaction surface: Engagements.SavedSearchesRepository.run_saved_search/2
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "Cross-account run_search call returns not_found" do
    scenario "Account B cannot run Account A's saved search" do
      given_ "Account A owns SavedSearch S, Dave is signed in on Account B", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        venue_a = Fixtures.venue_fixture(scope_a, %{source: :reddit, identifier: "elixir"})

        {:ok, saved_search} =
          SavedSearchesRepository.create_saved_search(scope_a, %{
            name: "a only",
            query: "elixir",
            venue_ids: [venue_a.id]
          })

        {:ok,
         Map.merge(context, %{
           scope_b: scope_b,
           saved_search_id: saved_search.id
         })}
      end

      when_ "Dave's scope calls run_saved_search with A's search id", context do
        result = SavedSearchesRepository.run_saved_search(context.scope_b, context.saved_search_id)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response is {:error, :not_found}", context do
        assert context.result == {:error, :not_found}
        {:ok, context}
      end
    end
  end
end
