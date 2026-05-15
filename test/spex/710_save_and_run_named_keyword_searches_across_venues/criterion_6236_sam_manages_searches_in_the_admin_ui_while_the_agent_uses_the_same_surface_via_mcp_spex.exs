defmodule MarketMySpecSpex.Story710.Criterion6236Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6236 — Sam manages searches in the admin UI while the agent
  uses the same surface via MCP.

  Both the LiveView admin and the MCP tool surface read/write the same
  SavedSearch records. The agent calling list_saved_searches sees exactly
  what the admin UI shows. Until SearchLive.Index ships, the in-process
  repository call stands in for both surfaces.

  Interaction surface: Engagements.SavedSearchesRepository.list_saved_searches/1
  + future SearchLive.Index LiveView.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "Both surfaces (admin UI + MCP) read the same SavedSearch records" do
    scenario "list_saved_searches returns the searches Sam created via the repo" do
      given_ "Sam has two SavedSearches on his account", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, _} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "elixir testing",
            query: "elixir testing",
            venue_ids: [venue.id]
          })

        {:ok, _} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "credo",
            query: "credo",
            venue_ids: [venue.id]
          })

        {:ok, Map.put(context, :scope, scope)}
      end

      when_ "the agent calls list_saved_searches on the scope", context do
        results = SavedSearchesRepository.list_saved_searches(context.scope)
        {:ok, Map.put(context, :results, results)}
      end

      then_ "the result contains both searches preloaded with their venues", context do
        assert length(context.results) == 2

        names = Enum.map(context.results, & &1.name) |> Enum.sort()
        assert names == ["credo", "elixir testing"]

        Enum.each(context.results, fn search ->
          assert is_list(search.venues),
                 "expected venues preloaded on every result"
        end)

        {:ok, context}
      end
    end
  end
end
