defmodule MarketMySpecSpex.Story705.Criterion6120Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6120 — Results are sourced from Reddit and ElixirForum behind a common
  Source behaviour so adding a third platform later is additive.

  The SearchEngagements tool fans out to Reddit and ElixirForum via a common
  Source behaviour. Both source modules implement validate_venue/1 and search/2,
  meaning a third source can be added without touching the orchestrator. This
  spec verifies the Source behaviour contract is satisfied by both adapters.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Source.ElixirForum

  spex "results are sourced from Reddit and ElixirForum behind a common Source behaviour" do
    scenario "Reddit adapter satisfies the Source behaviour contract" do
      given_ "a Reddit venue identifier", context do
        venue = %{source: "reddit", identifier: "elixir", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "validate_venue is called with a valid subreddit name", context do
        result = Reddit.validate_venue("elixir")
        {:ok, Map.put(context, :validate_result, result)}
      end

      then_ "validation returns :ok for a well-formed subreddit name", context do
        assert context.validate_result == :ok,
               "expected Reddit.validate_venue/1 to return :ok for 'elixir', got: #{inspect(context.validate_result)}"

        {:ok, context}
      end

      when_ "search/2 is called with a venue and query", context do
        {:ok, results} = Reddit.search(context.venue, "elixir testing")
        {:ok, Map.put(context, :search_results, results)}
      end

      then_ "search returns a list (even if empty at the scaffold stage)", context do
        assert is_list(context.search_results),
               "expected Reddit.search/2 to return a list, got: #{inspect(context.search_results)}"

        {:ok, context}
      end
    end

    scenario "ElixirForum adapter satisfies the Source behaviour contract" do
      given_ "an ElixirForum venue identifier", context do
        venue = %{source: "elixirforum", identifier: "phoenix-forum", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "validate_venue is called with a valid category identifier", context do
        result = ElixirForum.validate_venue("phoenix-forum")
        {:ok, Map.put(context, :validate_result, result)}
      end

      then_ "validation returns :ok for a well-formed ElixirForum identifier", context do
        assert context.validate_result == :ok,
               "expected ElixirForum.validate_venue/1 to return :ok for 'phoenix-forum', got: #{inspect(context.validate_result)}"

        {:ok, context}
      end

      when_ "search/2 is called with a venue and query", context do
        {:ok, results} = ElixirForum.search(context.venue, "elixir testing")
        {:ok, Map.put(context, :search_results, results)}
      end

      then_ "search returns a list (even if empty at the scaffold stage)", context do
        assert is_list(context.search_results),
               "expected ElixirForum.search/2 to return a list, got: #{inspect(context.search_results)}"

        {:ok, context}
      end
    end
  end
end
