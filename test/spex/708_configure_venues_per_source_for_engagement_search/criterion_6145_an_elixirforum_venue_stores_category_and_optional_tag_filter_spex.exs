defmodule MarketMySpecSpex.Story708.Criterion6145Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6145 — An ElixirForum venue stores category and optional tag filter.

  ElixirForum venues use the identifier field to store both the category slug
  and an optional tag in the format "category-slug" or "category-slug:tag".
  Both forms are accepted and persisted correctly.

  Interaction surface: Venue schema + database (integration).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Repo
  alias MarketMySpecSpex.Fixtures

  spex "an ElixirForum venue stores category and optional tag filter" do
    scenario "an ElixirForum venue with only a category slug is persisted" do
      given_ "an ElixirForum venue with a category-only identifier", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)

        attrs = %{
          account_id: account.id,
          source: :elixirforum,
          identifier: "phoenix-forum",
          weight: 1.0,
          enabled: true
        }

        {:ok, Map.merge(context, %{account: account, attrs: attrs})}
      end

      when_ "the venue is inserted", context do
        {:ok, venue} = Repo.insert(Venue.changeset(%Venue{}, context.attrs))
        {:ok, Map.put(context, :venue, venue)}
      end

      then_ "the identifier is stored as 'phoenix-forum'", context do
        assert context.venue.identifier == "phoenix-forum",
               "expected identifier 'phoenix-forum', got: #{inspect(context.venue.identifier)}"

        {:ok, context}
      end

      then_ "the source is stored as :elixirforum", context do
        assert context.venue.source == :elixirforum,
               "expected source :elixirforum, got: #{inspect(context.venue.source)}"

        {:ok, context}
      end
    end

    scenario "an ElixirForum venue with a category:tag identifier is persisted" do
      given_ "an ElixirForum venue with a category:tag identifier", context do
        user = Fixtures.user_fixture()
        account = Fixtures.account_fixture(user)

        attrs = %{
          account_id: account.id,
          source: :elixirforum,
          identifier: "phoenix-forum:ai",
          weight: 1.2,
          enabled: true
        }

        {:ok, Map.merge(context, %{account: account, attrs: attrs})}
      end

      when_ "the venue is inserted", context do
        {:ok, venue} = Repo.insert(Venue.changeset(%Venue{}, context.attrs))
        {:ok, Map.put(context, :venue, venue)}
      end

      then_ "the identifier preserves the tag filter 'phoenix-forum:ai'", context do
        assert context.venue.identifier == "phoenix-forum:ai",
               "expected identifier 'phoenix-forum:ai', got: #{inspect(context.venue.identifier)}"

        {:ok, context}
      end

      then_ "the venue can be retrieved with its tag filter intact", context do
        retrieved = Repo.get!(Venue, context.venue.id)

        assert retrieved.identifier == "phoenix-forum:ai",
               "expected retrieved identifier to be 'phoenix-forum:ai', " <>
                 "got: #{inspect(retrieved.identifier)}"

        {:ok, context}
      end
    end
  end
end
