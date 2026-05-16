defmodule MarketMySpecSpex.Story705.Criterion6289Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities
  Criterion 6289 — Each result includes title, source, URL, score/upvotes,
  reply count, recency, and a snippet.

  Drives the `search_engagements` MCP tool against a cassette-replayed
  Reddit listing with two known threads. Asserts every candidate carries
  the canonical shape (`title, source, url, score, reply_count, recency,
  snippet`) and that the values map back to the Reddit listing data
  (title strings, score/num_comments numerics, permalink-derived URL,
  created_utc-derived recency, selftext-derived snippet).

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.RedditHelpers

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "each result includes title, source, URL, score, reply count, recency, snippet" do
    scenario "candidates from a Reddit listing carry the canonical shape" do
      given_ "an account with one enabled Reddit venue (r/elixir) and a cassette with 2 threads",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        _venue =
          Fixtures.venue_fixture(scope, %{
            source: :reddit,
            identifier: "elixir",
            weight: 1.0,
            enabled: true
          })

        RedditHelpers.build_search_cassette!("crit_6289_shape",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{
              title: "Phoenix LiveView form patterns",
              score: 42,
              num_comments: 7,
              created_utc: 1_711_000_000.0,
              id: "abc111",
              permalink: "/r/elixir/comments/abc111/phoenix_liveview_form_patterns/",
              selftext: "I've been refactoring our LiveView forms and noticed a pattern..."
            },
            %{
              title: "Ash incremental migration story",
              score: 17,
              num_comments: 3,
              created_utc: 1_711_100_000.0,
              id: "abc222",
              permalink: "/r/elixir/comments/abc222/ash_incremental_migration_story/",
              selftext: "Adopting Ash piecemeal in a 4-year-old Phoenix app..."
            }
          ]
        )

        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the LLM calls search_engagements with the keyword 'elixir'", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6289_shape", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the response carries two candidates with the canonical shape", context do
        candidates = context.payload["candidates"]

        refute Enum.empty?(candidates),
               "expected a non-empty candidate list (cassette has 2 results)"

        assert length(candidates) == 2,
               "expected exactly 2 candidates, got #{length(candidates)}"

        for candidate <- candidates do
          for key <- ~w(title source url score reply_count recency snippet) do
            assert Map.has_key?(candidate, key),
                   "expected candidate to have '#{key}' key, got: #{inspect(Map.keys(candidate))}"
          end

          assert candidate["source"] == "reddit"
          assert is_binary(candidate["title"])
          assert is_binary(candidate["url"])
          assert String.starts_with?(candidate["url"], "https://www.reddit.com/")
          assert is_number(candidate["score"])
          assert is_number(candidate["reply_count"])
          assert candidate["recency"] != nil
          assert is_binary(candidate["snippet"])
        end

        {:ok, context}
      end
    end
  end
end
