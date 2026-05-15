defmodule MarketMySpecSpex.Story710.Criterion6235Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6235 — run_search delegates to the shared orchestrator and
  persists nothing.

  run_saved_search/2 returns the same `%{candidates, failures}` envelope as
  the ad-hoc Engagements.Search.search/3 orchestrator, and persists no
  run-history rows. We assert the envelope shape and that no auxiliary
  history table has been added to the SavedSearch schema (no `last_run_at`
  or `run_count` fields).

  Interaction surface: Engagements.SavedSearchesRepository.run_saved_search/2
  + SavedSearch schema introspection.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearch
  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "run_search delegates to the shared orchestrator and persists nothing" do
    scenario "the envelope matches ad-hoc search and the schema has no run-history fields" do
      given_ "Sam has a SavedSearch", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, saved_search} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "elixir hiring",
            query: "elixir hiring",
            venue_ids: [venue.id]
          })

        {:ok, Map.merge(context, %{scope: scope, saved_search: saved_search})}
      end

      when_ "the agent calls run_saved_search", context do
        result = SavedSearchesRepository.run_saved_search(context.scope, context.saved_search.id)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the envelope matches and the schema has no run-history fields", context do
        assert {:ok, %{candidates: candidates, failures: failures}} = context.result
        assert is_list(candidates)
        assert is_list(failures)

        # Recipe-only: no `last_run_at` / `run_count` on the schema.
        fields = SavedSearch.__schema__(:fields)
        refute :last_run_at in fields
        refute :run_count in fields

        {:ok, context}
      end
    end
  end
end
