defmodule MarketMySpecSpex.Story710.Criterion6229Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6229 — Creating a search with empty venue selection is rejected.

  A SavedSearch must have at least one venue selector — either at least one
  linked venue id or at least one source wildcard. Creating with neither
  fails before insert.

  Interaction surface: Engagements.SavedSearchesRepository.create_saved_search/2
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpecSpex.Fixtures

  spex "Creating a search with empty venue selection is rejected" do
    scenario "create_saved_search with no venue_ids and no source_wildcards returns an error" do
      given_ "Sam has an account but is about to skip the venue selection", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.put(context, :scope, scope)}
      end

      when_ "Sam calls create_saved_search with no venue_ids and no source_wildcards",
            context do
        result =
          SavedSearchesRepository.create_saved_search(context.scope, %{
            name: "needs venues",
            query: "anything",
            venue_ids: [],
            source_wildcards: []
          })

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the result is an error tagged with a changeset on venue_ids", context do
        assert {:error, %Ecto.Changeset{} = changeset} = context.result

        assert Keyword.has_key?(changeset.errors, :venue_ids),
               "expected a :venue_ids error, got #{inspect(changeset.errors)}"

        {:ok, context}
      end
    end
  end
end
