defmodule MarketMySpecSpex.Story710.Criterion6231Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6231 — Renaming a search to a name already taken on the same
  account fails.

  Per-account name uniqueness is enforced on update as well as create. A
  rename collision against an existing SavedSearch on the same account is
  rejected and the original search keeps its name.

  Interaction surface: Engagements.SavedSearchesRepository.update_saved_search/3
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "Renaming a search to a name already taken on the same account fails" do
    scenario "update_saved_search rejects rename collision and preserves original" do
      given_ "Sam has two SavedSearches \"elixir testing\" and \"credo nitpicks\"",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, first} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "elixir testing",
            query: "elixir testing",
            venue_ids: [venue.id]
          })

        {:ok, second} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "credo nitpicks",
            query: "credo",
            venue_ids: [venue.id]
          })

        {:ok,
         Map.merge(context, %{scope: scope, first: first, second: second})}
      end

      when_ "Sam renames \"credo nitpicks\" to \"elixir testing\"", context do
        result =
          SavedSearchesRepository.update_saved_search(context.scope, context.second.id, %{
            name: "elixir testing"
          })

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the update is rejected with a changeset error on :name and the original is preserved",
            context do
        assert {:error, %Ecto.Changeset{} = changeset} = context.result
        assert Keyword.has_key?(changeset.errors, :name)

        {:ok, reloaded} =
          SavedSearchesRepository.get_saved_search(context.scope, context.second.id)

        assert reloaded.name == "credo nitpicks"

        {:ok, context}
      end
    end
  end
end
