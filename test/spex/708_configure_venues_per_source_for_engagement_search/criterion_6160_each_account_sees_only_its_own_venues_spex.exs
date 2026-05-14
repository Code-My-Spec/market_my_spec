defmodule MarketMySpecSpex.Story708.Criterion6160Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6160 — Each account sees only its own venues.

  Venues are scoped to accounts via the account_id foreign key. Account A
  cannot see venues belonging to Account B. The Venue schema enforces this
  at the database level via the association, and queries must filter by
  account_id.

  Interaction surface: Venue schema + database (integration).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures
  import Ecto.Query

  spex "each account sees only its own venues" do
    scenario "venues inserted for account A are not returned when querying for account B" do
      given_ "two accounts, each with one venue", context do
        user_a = Fixtures.user_fixture()
        account_a = Fixtures.account_fixture(user_a)

        user_b = Fixtures.user_fixture()
        account_b = Fixtures.account_fixture(user_b)

        {:ok, venue_a} =
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
           venue_a: venue_a,
           venue_b: venue_b
         })}
      end

      when_ "venues are queried for account A", context do
        venues_for_a =
          Repo.all(from(v in Venue, where: v.account_id == ^context.account_a.id))

        {:ok, Map.put(context, :venues_for_a, venues_for_a)}
      end

      then_ "only account A's venue is returned", context do
        venue_ids = Enum.map(context.venues_for_a, & &1.id)

        assert context.venue_a.id in venue_ids,
               "expected account A's venue to be in the results"

        refute context.venue_b.id in venue_ids,
               "expected account B's venue NOT to appear in account A's query"

        {:ok, context}
      end

      when_ "venues are queried for account B", context do
        venues_for_b =
          Repo.all(from(v in Venue, where: v.account_id == ^context.account_b.id))

        {:ok, Map.put(context, :venues_for_b, venues_for_b)}
      end

      then_ "only account B's venue is returned", context do
        venue_ids = Enum.map(context.venues_for_b, & &1.id)

        assert context.venue_b.id in venue_ids,
               "expected account B's venue to be in the results"

        refute context.venue_a.id in venue_ids,
               "expected account A's venue NOT to appear in account B's query"

        {:ok, context}
      end
    end
  end
end
