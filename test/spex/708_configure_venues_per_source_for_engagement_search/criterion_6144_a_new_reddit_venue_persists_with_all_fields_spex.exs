defmodule MarketMySpecSpex.Story708.Criterion6144Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6144 — A new Reddit venue persists with all fields.

  When a Reddit venue is created via Venue.changeset/2 and inserted into the
  database, all four fields (source, identifier, weight, enabled) are stored
  and can be retrieved. The account association is enforced.

  Interaction surface: Venue schema + database (integration).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures

  spex "a new Reddit venue persists with all fields" do
    scenario "inserting a Reddit venue stores source, identifier, weight, and enabled" do
      given_ "an account and Reddit venue attributes", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)

        attrs = %{
          account_id: account.id,
          source: :reddit,
          identifier: "elixir",
          weight: 1.5,
          enabled: true
        }

        {:ok, Map.merge(context, %{account: account, attrs: attrs})}
      end

      when_ "the venue is inserted into the database", context do
        {:ok, venue} = Repo.insert(Venue.changeset(%Venue{}, context.attrs))
        {:ok, Map.put(context, :venue, venue)}
      end

      then_ "the persisted venue has source :reddit", context do
        assert context.venue.source == :reddit,
               "expected source to be :reddit, got: #{inspect(context.venue.source)}"

        {:ok, context}
      end

      then_ "the persisted venue has identifier 'elixir'", context do
        assert context.venue.identifier == "elixir",
               "expected identifier 'elixir', got: #{inspect(context.venue.identifier)}"

        {:ok, context}
      end

      then_ "the persisted venue has weight 1.5", context do
        assert context.venue.weight == 1.5,
               "expected weight 1.5, got: #{inspect(context.venue.weight)}"

        {:ok, context}
      end

      then_ "the persisted venue has enabled true", context do
        assert context.venue.enabled == true,
               "expected enabled true, got: #{inspect(context.venue.enabled)}"

        {:ok, context}
      end

      then_ "the venue can be retrieved from the database", context do
        retrieved = Repo.get!(Venue, context.venue.id)

        assert retrieved.id == context.venue.id
        assert retrieved.source == :reddit
        assert retrieved.identifier == "elixir"
        assert retrieved.account_id == context.account.id

        {:ok, context}
      end
    end
  end
end
