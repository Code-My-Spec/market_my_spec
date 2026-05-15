defmodule MarketMySpecSpex.Story710.Criterion6230Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6230 — Two accounts can each have a search named "elixir testing".

  Name uniqueness is enforced per-account, not globally. Two unrelated
  accounts can each create a SavedSearch named "elixir testing" and both
  succeed.

  Interaction surface: Engagements.SavedSearchesRepository.create_saved_search/2
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "Two accounts can each have a search named \"elixir testing\"" do
    scenario "create_saved_search succeeds in both accounts with the same name" do
      given_ "two distinct accounts each with one Reddit venue", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        venue_a = Fixtures.venue_fixture(scope_a, %{source: :reddit, identifier: "elixir"})
        venue_b = Fixtures.venue_fixture(scope_b, %{source: :reddit, identifier: "elixir"})

        {:ok,
         Map.merge(context, %{
           scope_a: scope_a,
           scope_b: scope_b,
           venue_a_id: venue_a.id,
           venue_b_id: venue_b.id
         })}
      end

      when_ "each account creates a SavedSearch named \"elixir testing\"", context do
        result_a =
          SavedSearchesRepository.create_saved_search(context.scope_a, %{
            name: "elixir testing",
            query: "elixir testing",
            venue_ids: [context.venue_a_id]
          })

        result_b =
          SavedSearchesRepository.create_saved_search(context.scope_b, %{
            name: "elixir testing",
            query: "elixir testing",
            venue_ids: [context.venue_b_id]
          })

        {:ok, Map.merge(context, %{result_a: result_a, result_b: result_b})}
      end

      then_ "both creates succeed and the searches are scoped to their accounts",
            context do
        assert {:ok, search_a} = context.result_a
        assert {:ok, search_b} = context.result_b

        assert search_a.account_id == context.scope_a.active_account_id
        assert search_b.account_id == context.scope_b.active_account_id
        assert search_a.id != search_b.id

        {:ok, context}
      end
    end
  end
end
