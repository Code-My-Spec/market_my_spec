defmodule MarketMySpecSpex.Story708.Criterion6142Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6142 — The existing slash-command venue lists (r/ClaudeAI,
  r/ChatGPTCoding, r/vibecoding, r/elixir, r/programming, r/AskProgramming for
  Reddit; Your Libraries, Phoenix Forum, Chat, Questions/Help for ElixirForum,
  plus tags ai/llm/testing/bdd/credo) can be seeded on first run.

  The Venue schema and validation rules accept all identifiers from the known
  good venue lists. Each known subreddit and ElixirForum category validates
  against Source.validate_venue/1 without error.

  Interaction surface: Venue schema changeset (unit).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Venue

  @known_reddit_venues ~w(ClaudeAI ChatGPTCoding vibecoding elixir programming AskProgramming)
  @known_elixirforum_venues ~w(your-libraries phoenix-forum chat questions-help)

  spex "known venue lists validate cleanly against source rules" do
    scenario "all known Reddit subreddits pass validation" do
      given_ "the list of known Reddit venues", context do
        {:ok, Map.put(context, :venues, @known_reddit_venues)}
      end

      when_ "each subreddit is validated via Venue.changeset/2", context do
        results =
          Enum.map(context.venues, fn identifier ->
            attrs = %{
              account_id: Ecto.UUID.generate(),
              source: :reddit,
              identifier: identifier
            }

            changeset = Venue.changeset(%Venue{}, attrs)
            {identifier, changeset.valid?, changeset.errors}
          end)

        {:ok, Map.put(context, :results, results)}
      end

      then_ "all known Reddit venues are valid", context do
        failures =
          Enum.reject(context.results, fn {_id, valid, _errors} -> valid end)

        assert failures == [],
               "expected all known Reddit venues to be valid, but these failed: " <>
                 "#{inspect(Enum.map(failures, fn {id, _, errs} -> {id, errs} end))}"

        {:ok, context}
      end
    end

    scenario "all known ElixirForum categories pass validation" do
      given_ "the list of known ElixirForum venues", context do
        {:ok, Map.put(context, :venues, @known_elixirforum_venues)}
      end

      when_ "each category is validated via Venue.changeset/2", context do
        results =
          Enum.map(context.venues, fn identifier ->
            attrs = %{
              account_id: Ecto.UUID.generate(),
              source: :elixirforum,
              identifier: identifier
            }

            changeset = Venue.changeset(%Venue{}, attrs)
            {identifier, changeset.valid?, changeset.errors}
          end)

        {:ok, Map.put(context, :results, results)}
      end

      then_ "all known ElixirForum venues are valid", context do
        failures =
          Enum.reject(context.results, fn {_id, valid, _errors} -> valid end)

        assert failures == [],
               "expected all known ElixirForum venues to be valid, but these failed: " <>
                 "#{inspect(Enum.map(failures, fn {id, _, errs} -> {id, errs} end))}"

        {:ok, context}
      end
    end

    scenario "ElixirForum venues with optional tag filters validate cleanly" do
      given_ "ElixirForum venue identifiers with tag filters", context do
        tagged = ~w(phoenix-forum:ai phoenix-forum:llm questions-help:bdd questions-help:credo)
        {:ok, Map.put(context, :venues, tagged)}
      end

      when_ "each tagged identifier is validated", context do
        results =
          Enum.map(context.venues, fn identifier ->
            attrs = %{
              account_id: Ecto.UUID.generate(),
              source: :elixirforum,
              identifier: identifier
            }

            changeset = Venue.changeset(%Venue{}, attrs)
            {identifier, changeset.valid?, changeset.errors}
          end)

        {:ok, Map.put(context, :results, results)}
      end

      then_ "all tagged ElixirForum venues are valid", context do
        failures =
          Enum.reject(context.results, fn {_id, valid, _errors} -> valid end)

        assert failures == [],
               "expected tagged ElixirForum venues to be valid, failed: " <>
                 "#{inspect(Enum.map(failures, fn {id, _, errs} -> {id, errs} end))}"

        {:ok, context}
      end
    end
  end
end
