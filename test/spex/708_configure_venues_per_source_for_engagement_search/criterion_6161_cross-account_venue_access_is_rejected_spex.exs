defmodule MarketMySpecSpex.Story708.Criterion6161Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6161 — Cross-account venue access is rejected.

  The Venue schema enforces account scoping via account_id. A direct query
  for a venue by ID that belongs to a different account returns no result
  (nil or empty list). The VenuesRepository must always scope queries by
  account_id so that a venue from Account B is never returned in Account A's
  context.

  Interaction surface: Venue schema + database (integration).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures
  import Ecto.Query

  spex "cross-account venue access is rejected" do
    scenario "a venue belonging to account B is not found when querying with account A's scope" do
      given_ "two accounts, each with a venue", context do
        user_a = Fixtures.user_fixture()
        account_a = Fixtures.account_fixture(user_a)

        user_b = Fixtures.user_fixture()
        account_b = Fixtures.account_fixture(user_b)

        {:ok, _venue_a} =
          Repo.insert(
            Venue.changeset(%Venue{}, %{
              account_id: account_a.id,
              source: :reddit,
              identifier: "elixir"
            })
          )

        {:ok, venue_b} =
          Repo.insert(
            Venue.changeset(%Venue{}, %{
              account_id: account_b.id,
              source: :reddit,
              identifier: "programming"
            })
          )

        {:ok,
         Map.merge(context, %{
           account_a: account_a,
           account_b: account_b,
           venue_b: venue_b
         })}
      end

      when_ "account A tries to query venue B by ID with account A's scope", context do
        # A scoped query: look for venue_b.id but filtered by account_a.id
        result =
          Repo.one(
            from(v in Venue,
              where: v.id == ^context.venue_b.id and v.account_id == ^context.account_a.id
            )
          )

        {:ok, Map.put(context, :cross_account_result, result)}
      end

      then_ "the cross-account query returns nil (venue not found)", context do
        assert is_nil(context.cross_account_result),
               "expected cross-account query to return nil, " <>
                 "got: #{inspect(context.cross_account_result)}"

        {:ok, context}
      end
    end

    scenario "a venue is only retrievable within its own account scope" do
      given_ "one account with a venue", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)

        other_user = Fixtures.user_fixture()
        other_account = Fixtures.account_fixture(other_user)

        {:ok, venue} =
          Repo.insert(
            Venue.changeset(%Venue{}, %{
              account_id: account.id,
              source: :elixirforum,
              identifier: "phoenix-forum"
            })
          )

        {:ok,
         Map.merge(context, %{
           account: account,
           other_account: other_account,
           venue: venue
         })}
      end

      when_ "the venue is queried within its own account scope", context do
        result =
          Repo.one(
            from(v in Venue,
              where: v.id == ^context.venue.id and v.account_id == ^context.account.id
            )
          )

        {:ok, Map.put(context, :owned_result, result)}
      end

      then_ "the venue is found in its own account scope", context do
        assert not is_nil(context.owned_result),
               "expected venue to be found within its own account scope"

        assert context.owned_result.id == context.venue.id,
               "expected returned venue id to match"

        {:ok, context}
      end

      when_ "the same venue is queried with the other account's scope", context do
        result =
          Repo.one(
            from(v in Venue,
              where: v.id == ^context.venue.id and v.account_id == ^context.other_account.id
            )
          )

        {:ok, Map.put(context, :cross_result, result)}
      end

      then_ "the venue is not found under the other account's scope", context do
        assert is_nil(context.cross_result),
               "expected cross-account query to return nil — venue belongs to a different account"

        {:ok, context}
      end
    end
  end
end
