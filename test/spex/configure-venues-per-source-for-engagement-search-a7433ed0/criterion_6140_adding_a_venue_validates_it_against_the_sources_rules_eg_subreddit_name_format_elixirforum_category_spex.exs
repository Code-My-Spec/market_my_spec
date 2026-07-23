defmodule MarketMySpecSpex.Story708.Criterion6140Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6140 — Adding a venue validates it against the source's rules (e.g.,
  subreddit name format, ElixirForum category id exists).

  The Venue changeset delegates identifier validation to the source adapter.
  Reddit venues must have a subreddit name matching the 3-21 char alphanumeric
  pattern. Invalid identifiers are rejected with a descriptive error.

  Interaction surface: Venue schema changeset + VenueLive.Index form validation.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue

  spex "adding a venue validates it against the source's rules" do
    scenario "a Reddit venue with a valid subreddit name is accepted" do
      given_ "venue attributes for a valid subreddit", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          identifier: "elixir",
          weight: 1.0,
          enabled: true
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid", context do
        assert context.changeset.valid?,
               "expected changeset to be valid for a well-formed subreddit name, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end
    end

    scenario "a Reddit venue with an invalid subreddit name is rejected" do
      given_ "venue attributes for an invalid subreddit (too short)", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          identifier: "ab",
          weight: 1.0,
          enabled: true
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid", context do
        refute context.changeset.valid?,
               "expected changeset to be invalid for a subreddit name that is too short"

        {:ok, context}
      end

      then_ "the identifier error explains the validation failure", context do
        errors = context.changeset.errors

        assert Keyword.has_key?(errors, :identifier),
               "expected an :identifier error for an invalid subreddit name, " <>
                 "got: #{inspect(errors)}"

        {:ok, context}
      end
    end

    scenario "a Reddit venue with special characters in the subreddit name is rejected" do
      given_ "venue attributes with an invalid subreddit containing hyphens", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :reddit,
          identifier: "my-subreddit!",
          weight: 1.0,
          enabled: true
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with an identifier error", context do
        refute context.changeset.valid?,
               "expected changeset to be invalid for 'my-subreddit!' (special chars)"

        assert Keyword.has_key?(context.changeset.errors, :identifier),
               "expected an identifier error, got: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end
    end

    scenario "an ElixirForum venue with a non-empty identifier is accepted" do
      given_ "venue attributes for a valid ElixirForum category", context do
        attrs = %{
          account_id: Ecto.UUID.generate(),
          source: :elixirforum,
          identifier: "phoenix-forum",
          weight: 1.0,
          enabled: true
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the Venue changeset is built", context do
        changeset = Venue.changeset(%Venue{}, context.attrs)
        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is valid", context do
        assert context.changeset.valid?,
               "expected ElixirForum venue with 'phoenix-forum' to be valid, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end
    end
  end
end
