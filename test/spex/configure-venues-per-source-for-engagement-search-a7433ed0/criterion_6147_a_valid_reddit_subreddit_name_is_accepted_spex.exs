defmodule MarketMySpecSpex.Story708.Criterion6147Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6147 — A valid Reddit subreddit name is accepted.

  The Reddit source adapter validates subreddit names against the 3-21 character
  alphanumeric (plus underscore) format. Well-formed names such as 'elixir',
  'ClaudeAI', and 'ChatGPTCoding' are accepted by both the Source adapter and
  the Venue changeset.

  Interaction surface: Source.Reddit.validate_venue/1 + Venue changeset (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Venue

  @valid_subreddits ~w(elixir ClaudeAI ChatGPTCoding vibecoding programming AskProgramming)

  spex "a valid Reddit subreddit name is accepted" do
    scenario "Reddit.validate_venue/1 returns :ok for all valid subreddit names" do
      given_ "a list of known valid subreddit names", context do
        {:ok, Map.put(context, :subreddits, @valid_subreddits)}
      end

      when_ "each subreddit is validated via Reddit.validate_venue/1", context do
        results =
          Enum.map(context.subreddits, fn name ->
            {name, Reddit.validate_venue(name)}
          end)

        {:ok, Map.put(context, :results, results)}
      end

      then_ "all valid subreddit names return :ok", context do
        failures =
          Enum.reject(context.results, fn {_name, result} -> result == :ok end)

        assert failures == [],
               "expected all valid subreddits to return :ok, but these failed: #{inspect(failures)}"

        {:ok, context}
      end
    end

    scenario "Venue.changeset/2 accepts a valid Reddit subreddit identifier" do
      given_ "a valid Reddit venue attributes", context do
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

      then_ "the changeset is valid and no identifier error is present", context do
        assert context.changeset.valid?,
               "expected Venue changeset to be valid for a valid subreddit, " <>
                 "errors: #{inspect(context.changeset.errors)}"

        refute Keyword.has_key?(context.changeset.errors, :identifier),
               "expected no identifier error for a valid subreddit"

        {:ok, context}
      end
    end

    scenario "single-word subreddits of minimum length (3 chars) are accepted" do
      given_ "a 3-character subreddit name", context do
        {:ok, Map.put(context, :identifier, "abc")}
      end

      when_ "validate_venue is called", context do
        result = Reddit.validate_venue(context.identifier)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "validation returns :ok for a 3-character name", context do
        assert context.result == :ok,
               "expected 'abc' (3 chars) to be valid, got: #{inspect(context.result)}"

        {:ok, context}
      end
    end
  end
end
