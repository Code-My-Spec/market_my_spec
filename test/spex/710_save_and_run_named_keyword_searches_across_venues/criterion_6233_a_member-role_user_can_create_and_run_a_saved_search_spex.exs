defmodule MarketMySpecSpex.Story710.Criterion6233Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6233 — A member-role user can create and run a saved search.

  Any account member (not just the owner) can create and run saved searches
  on their account. We assert the repository functions accept a member-role
  scope. The UI-level "click Run now" is exercised via story 710's
  LiveView spec elsewhere.

  Interaction surface: Engagements.SavedSearchesRepository.create_saved_search/2
  + run_saved_search/2.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "A member-role user can create and run a saved search" do
    scenario "member-scoped repo calls succeed without permission denials" do
      given_ "an account-scoped user (member role) with one Reddit venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, Map.merge(context, %{scope: scope, venue_id: venue.id})}
      end

      when_ "the user creates and runs a saved search", context do
        create_result =
          SavedSearchesRepository.create_saved_search(context.scope, %{
            name: "elixir testing",
            query: "elixir testing",
            venue_ids: [context.venue_id]
          })

        run_result =
          case create_result do
            {:ok, search} -> SavedSearchesRepository.run_saved_search(context.scope, search.id)
            other -> other
          end

        {:ok, Map.merge(context, %{create_result: create_result, run_result: run_result})}
      end

      then_ "both calls succeed and the run returns a candidates/failures envelope",
            context do
        assert {:ok, _} = context.create_result
        assert {:ok, %{candidates: _, failures: _}} = context.run_result

        {:ok, context}
      end
    end
  end
end
