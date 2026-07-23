defmodule MarketMySpecSpex.Story708.Criterion6148Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6148 — An invalid Reddit subreddit name is rejected with an error.

  The Reddit source adapter rejects subreddit names that are too short (< 3 chars),
  too long (> 21 chars), contain special characters, or contain spaces. The Venue
  changeset propagates this as an :identifier error.

  Interaction surface: Source.Reddit.validate_venue/1 + Venue changeset (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Venue

  spex "an invalid Reddit subreddit name is rejected with an error" do
    scenario "Reddit.validate_venue/1 returns an error for a too-short name" do
      given_ "a 2-character subreddit name", context do
        {:ok, Map.put(context, :identifier, "ab")}
      end

      when_ "validate_venue is called", context do
        result = Reddit.validate_venue(context.identifier)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "validation returns an error tuple", context do
        assert match?({:error, _}, context.result),
               "expected {:error, _} for a 2-char subreddit, got: #{inspect(context.result)}"

        {:ok, context}
      end
    end

    scenario "Reddit.validate_venue/1 returns an error for a name with hyphens" do
      given_ "a subreddit name with a hyphen", context do
        {:ok, Map.put(context, :identifier, "my-subreddit")}
      end

      when_ "validate_venue is called", context do
        result = Reddit.validate_venue(context.identifier)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "validation returns an error", context do
        assert match?({:error, _}, context.result),
               "expected {:error, _} for 'my-subreddit' (hyphens not allowed), " <>
                 "got: #{inspect(context.result)}"

        {:ok, context}
      end
    end

    scenario "Reddit.validate_venue/1 returns an error for a name that is too long" do
      given_ "a 22-character subreddit name", context do
        {:ok, Map.put(context, :identifier, String.duplicate("a", 22))}
      end

      when_ "validate_venue is called", context do
        result = Reddit.validate_venue(context.identifier)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "validation returns an error for the too-long name", context do
        assert match?({:error, _}, context.result),
               "expected {:error, _} for a 22-char name (max is 21), " <>
                 "got: #{inspect(context.result)}"

        {:ok, context}
      end
    end

    scenario "Venue.changeset/2 carries an :identifier error for an invalid subreddit" do
      given_ "a Venue with an invalid Reddit subreddit name", context do
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
               "expected changeset to be invalid for a too-short subreddit name"

        {:ok, context}
      end

      then_ "an :identifier error is present", context do
        assert Keyword.has_key?(context.changeset.errors, :identifier),
               "expected an :identifier error, got: #{inspect(context.changeset.errors)}"

        {:ok, context}
      end
    end
  end
end
