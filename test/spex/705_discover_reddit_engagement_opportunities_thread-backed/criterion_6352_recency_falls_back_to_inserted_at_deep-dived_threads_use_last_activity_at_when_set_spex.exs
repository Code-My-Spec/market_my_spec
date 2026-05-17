defmodule MarketMySpecSpex.Story705.Criterion6352Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6352 — Recency falls back to inserted_at; deep-dived
  threads use last_activity_at when set.

  Two Threads on the account:
  - T-cold: surfaced in a prior scan, never deep-read. last_activity_at
    is nil. Candidate.recency == Thread.inserted_at.
  - T-deep: surfaced in a prior scan AND deep-read recently via
    get_thread (story 706), so last_activity_at is set. Candidate.recency
    == Thread.last_activity_at.

  Depends on story 706 (deep-read) for the last_activity_at write path.

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

  # Recency may serialize as either an ISO8601 string (`"2026-05-14T12:00:00Z"`)
  # or a Unix epoch number (`1715688000`). Normalize to Unix int for comparison.
  defp recency_to_unix(value) when is_binary(value) do
    {:ok, dt, _} = DateTime.from_iso8601(value)
    DateTime.to_unix(dt)
  end

  defp recency_to_unix(value) when is_integer(value), do: value
  defp recency_to_unix(value) when is_float(value), do: trunc(value)
  defp recency_to_unix(other), do: flunk("unexpected recency type: #{inspect(other)}")

  spex "recency falls back to inserted_at; deep-dived threads use last_activity_at" do
    scenario "T-cold uses inserted_at; T-deep uses last_activity_at" do
      given_ "two pre-existing Threads (one cold, one deep-dived) and a cassette surfacing both",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        two_days_ago = DateTime.utc_now() |> DateTime.add(-2 * 24 * 3600)
        five_min_ago = DateTime.utc_now() |> DateTime.add(-300)

        cold_thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "cold_t3",
            url: "https://www.reddit.com/r/elixir/comments/cold_t3/_/",
            title: "Cold thread",
            inserted_at: two_days_ago
          })

        deep_thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "deep_t3",
            url: "https://www.reddit.com/r/elixir/comments/deep_t3/_/",
            title: "Deep-dived thread",
            inserted_at: DateTime.utc_now() |> DateTime.add(-3 * 24 * 3600),
            last_activity_at: five_min_ago
          })

        RedditHelpers.build_search_cassette!("crit_6352_recency",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Cold thread", score: 1, num_comments: 0, id: "cold_t3",
              permalink: "/r/elixir/comments/cold_t3/_/"},
            %{title: "Deep-dived thread", score: 1, num_comments: 0, id: "deep_t3",
              permalink: "/r/elixir/comments/deep_t3/_/"}
          ]
        )

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           cold_inserted_at: cold_thread.inserted_at,
           deep_last_activity_at: deep_thread.last_activity_at
         })}
      end

      when_ "search is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6352_recency", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "cold thread's recency equals its inserted_at; deep thread's equals last_activity_at (two distinct code paths)",
            context do
        candidates = context.payload["candidates"]

        refute Enum.empty?(candidates), "expected non-empty candidate list"
        assert length(candidates) == 2, "expected 2 candidates"

        cold = Enum.find(candidates, &(&1["url"] =~ "cold_t3"))
        deep = Enum.find(candidates, &(&1["url"] =~ "deep_t3"))

        assert cold, "expected cold-thread candidate in response"
        assert deep, "expected deep-dived candidate in response"

        # Compare to the explicit values we set in fixtures, allowing for
        # either ISO8601 string or Unix epoch serialization (impl-detail).
        cold_expected_unix = DateTime.to_unix(context.cold_inserted_at)
        deep_expected_unix = DateTime.to_unix(context.deep_last_activity_at)

        cold_actual_unix = recency_to_unix(cold["recency"])
        deep_actual_unix = recency_to_unix(deep["recency"])

        # Cold's recency must equal Thread.inserted_at (within ±2s for
        # truncation/serialization rounding).
        assert_in_delta cold_actual_unix, cold_expected_unix, 2,
                        "cold thread recency should equal inserted_at (#{cold_expected_unix}), got #{cold_actual_unix} — implementation may be using the wrong field"

        # Deep's recency must equal Thread.last_activity_at, NOT inserted_at
        # (their inserted_at is 3 days ago; last_activity_at is 5 min ago).
        assert_in_delta deep_actual_unix, deep_expected_unix, 2,
                        "deep thread recency should equal last_activity_at (#{deep_expected_unix}), got #{deep_actual_unix} — implementation may be falling back to inserted_at when last_activity_at is set"

        # And the two MUST diverge (proving the two distinct code paths).
        refute cold_actual_unix == deep_actual_unix,
               "expected cold and deep to use different fields (different code paths) — got identical recency #{cold_actual_unix}, implementation likely uses one field for both"

        {:ok, context}
      end
    end
  end
end
