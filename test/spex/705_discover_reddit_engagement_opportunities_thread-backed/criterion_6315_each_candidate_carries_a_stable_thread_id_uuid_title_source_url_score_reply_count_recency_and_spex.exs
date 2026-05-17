defmodule MarketMySpecSpex.Story705.Criterion6315Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6315 — Each candidate carries a stable thread_id (UUID),
  title, source, URL, score, reply_count, recency, and snippet.

  The Thread-backed redesign requires every candidate to include a
  stable UUID (the persisted Thread.id) so the agent can chain straight
  into get_thread / stage_response without parsing URLs. Plus the
  existing canonical fields: title, source, url, score, reply_count,
  recency, snippet.

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

  defp uuid?(value) when is_binary(value) do
    String.match?(value, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
  end

  defp uuid?(_), do: false

  spex "each candidate carries a stable thread_id (UUID) plus canonical metadata" do
    scenario "two-thread cassette yields candidates with thread_id + canonical fields" do
      given_ "an account with one enabled r/elixir venue and a cassette with 2 threads",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit,
          identifier: "elixir",
          enabled: true
        })

        RedditHelpers.build_search_cassette!("crit_6315_shape",
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

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "the LLM calls search_engagements with the keyword 'elixir'", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6315_shape", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the response carries two candidates with thread_id + canonical fields",
            context do
        candidates = context.payload["candidates"]

        refute Enum.empty?(candidates),
               "expected a non-empty candidate list (cassette has 2 results)"

        assert length(candidates) == 2,
               "expected exactly 2 candidates, got #{length(candidates)}"

        for candidate <- candidates do
          for key <- ~w(thread_id title source url score reply_count recency snippet) do
            assert Map.has_key?(candidate, key),
                   "expected candidate to have '#{key}' key, got: #{inspect(Map.keys(candidate))}"
          end

          assert uuid?(candidate["thread_id"]),
                 "expected thread_id to be a UUID, got: #{inspect(candidate["thread_id"])}"

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
