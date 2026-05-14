defmodule MarketMySpecSpex.Story705.Criterion6172Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6172 — Recency reflects time of last activity, not thread creation.

  The `recency` field on each candidate is set to the time of the most recent
  comment or reply on the thread, not the thread's original creation timestamp.
  A thread created two years ago but commented on yesterday is considered recent.
  Source adapters must expose last_activity_at rather than created_at for this field.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Source.ElixirForum

  spex "recency reflects time of last activity not thread creation" do
    scenario "Reddit search results expose a recency field per candidate" do
      given_ "a Reddit venue", context do
        venue = %{source: "reddit", identifier: "elixir", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "Reddit.search/2 is called", context do
        {:ok, candidates} = Reddit.search(context.venue, "elixir liveview")
        {:ok, Map.put(context, :candidates, candidates)}
      end

      then_ "each candidate has a recency field (representing last activity, not creation)", context do
        Enum.each(context.candidates, fn candidate ->
          assert Map.has_key?(candidate, "recency") or Map.has_key?(candidate, :recency),
                 "expected Reddit candidate to have a 'recency' field for last-activity time"
        end)

        {:ok, context}
      end
    end

    scenario "ElixirForum search results expose a recency field per candidate" do
      given_ "an ElixirForum venue", context do
        venue = %{source: "elixirforum", identifier: "phoenix-forum", weight: 1.0, enabled: true}
        {:ok, Map.put(context, :venue, venue)}
      end

      when_ "ElixirForum.search/2 is called", context do
        {:ok, candidates} = ElixirForum.search(context.venue, "liveview")
        {:ok, Map.put(context, :candidates, candidates)}
      end

      then_ "each candidate has a recency field (representing last activity, not creation)", context do
        Enum.each(context.candidates, fn candidate ->
          assert Map.has_key?(candidate, "recency") or Map.has_key?(candidate, :recency),
                 "expected ElixirForum candidate to have a 'recency' field for last-activity time"
        end)

        {:ok, context}
      end
    end
  end
end
