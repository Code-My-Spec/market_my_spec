defmodule MarketMySpecSpex.Story710.Criterion6232Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6232 — run_search interprets OR alternates and quoted phrases.

  The saved query is stored as a single Google-style string. When run_search
  fires, the orchestrator parses operators at run time — quoted phrases stay
  together and OR-separated terms produce alternates. The candidate list is
  the union, deduplicated by URL.

  Interaction surface: Engagements.SavedSearchesRepository.run_saved_search/2
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "run_search interprets OR alternates and quoted phrases" do
    scenario "a Google-style query persists and run_saved_search returns a result envelope" do
      given_ "Sam has a SavedSearch with the query `\"elixir testing\" OR credo`",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, saved_search} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "elixir testing",
            query: ~s("elixir testing" OR credo),
            venue_ids: [venue.id]
          })

        {:ok, Map.merge(context, %{scope: scope, saved_search: saved_search})}
      end

      when_ "the agent calls run_saved_search on the saved search", context do
        result = SavedSearchesRepository.run_saved_search(context.scope, context.saved_search.id)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response carries the candidates/failures envelope and the stored query is unchanged",
            context do
        assert {:ok, %{candidates: candidates, failures: failures}} = context.result
        assert is_list(candidates)
        assert is_list(failures)

        assert context.saved_search.query == ~s("elixir testing" OR credo)

        {:ok, context}
      end
    end
  end
end
