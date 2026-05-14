defmodule MarketMySpecSpex.Story705.Criterion6164Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6164 — Reddit and ElixirForum candidates share the same shape.

  Both source adapters normalize their raw API responses into a common candidate
  shape before returning to the orchestrator. The shape includes: title, source,
  url, score, reply_count, recency, and snippet. This normalization means the
  search orchestrator and the LLM never need to branch on source type when
  rendering the candidate list.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Source.ElixirForum

  spex "Reddit and ElixirForum candidates share the same shape" do
    scenario "Reddit search/2 returns a list of maps with the expected candidate fields" do
      given_ "a Reddit venue", context do
        venue = %{source: "reddit", identifier: "elixir", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "Reddit.search/2 is called", context do
        {:ok, candidates} = Reddit.search(context.venue, "testing")
        {:ok, Map.put(context, :candidates, candidates)}
      end

      then_ "each Reddit candidate (if any) carries the expected shape", context do
        Enum.each(context.candidates, fn candidate ->
          required_keys = ~w(title source url score reply_count recency snippet)

          Enum.each(required_keys, fn key ->
            assert Map.has_key?(candidate, key),
                   "expected Reddit candidate to have '#{key}' field, got: #{inspect(Map.keys(candidate))}"
          end)

          assert candidate["source"] == "reddit",
                 "expected candidate source to be 'reddit', got: #{inspect(candidate["source"])}"
        end)

        {:ok, context}
      end
    end

    scenario "ElixirForum search/2 returns a list of maps with the expected candidate fields" do
      given_ "an ElixirForum venue", context do
        venue = %{source: "elixirforum", identifier: "phoenix-forum", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "ElixirForum.search/2 is called", context do
        {:ok, candidates} = ElixirForum.search(context.venue, "testing")
        {:ok, Map.put(context, :candidates, candidates)}
      end

      then_ "each ElixirForum candidate (if any) carries the expected shape", context do
        Enum.each(context.candidates, fn candidate ->
          required_keys = ~w(title source url score reply_count recency snippet)

          Enum.each(required_keys, fn key ->
            assert Map.has_key?(candidate, key),
                   "expected ElixirForum candidate to have '#{key}' field, got: #{inspect(Map.keys(candidate))}"
          end)

          assert candidate["source"] == "elixirforum",
                 "expected candidate source to be 'elixirforum', got: #{inspect(candidate["source"])}"
        end)

        {:ok, context}
      end
    end
  end
end
