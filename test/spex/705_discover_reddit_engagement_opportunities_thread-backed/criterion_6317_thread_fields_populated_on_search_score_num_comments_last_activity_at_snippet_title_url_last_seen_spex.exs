defmodule MarketMySpecSpex.Story705.Criterion6317Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6317 — Thread fields populated on search: score, num_comments,
  last_activity_at, snippet, title, url, last_seen_at; fetched_at is left
  untouched (only updated by get_thread).

  The candidate's response shape carries score, num_comments (renamed
  reply_count in the API but mapped from num_comments), title, url, and
  recency — those map to the persisted Thread fields. last_seen_at is
  observable indirectly: a thread surfaced twice has its UUID stable,
  meaning the row was updated, not duplicated.

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

  spex "search populates Thread fields (score, num_comments, title, url, recency, snippet)" do
    scenario "candidate response carries the search-time field values" do
      given_ "an account with one enabled r/elixir venue and a cassette with a thread carrying specific score/num_comments/title/url/recency/snippet",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", enabled: true
        })

        RedditHelpers.build_search_cassette!("crit_6317_fields",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{
              title: "A specific title",
              score: 42,
              num_comments: 13,
              created_utc: 1_711_500_000.0,
              id: "fld1",
              permalink: "/r/elixir/comments/fld1/a_specific_title/",
              selftext: "A specific snippet body that should land in the candidate."
            }
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6317_fields", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the candidate carries the field values supplied by the cassette", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 1
        [c] = candidates

        assert c["title"] == "A specific title"
        assert c["score"] == 42
        assert c["reply_count"] == 13
        assert c["url"] == "https://www.reddit.com/r/elixir/comments/fld1/a_specific_title/"

        # Per Rule 8: recency is sourced from Thread.inserted_at (a DateTime),
        # not the raw Reddit `created_utc` float. Assert the field is populated
        # in a plausible serialized form (string or number) — exact value
        # depends on the impl's serialization choice (ISO8601 string vs Unix
        # epoch number). Criterion 6352 separately verifies inserted_at vs
        # last_activity_at code paths.
        assert c["recency"] != nil,
               "expected recency populated (from Thread.inserted_at per Rule 8), got nil"

        assert is_binary(c["recency"]) or is_number(c["recency"]),
               "expected recency as ISO8601 string or numeric epoch, got: #{inspect(c["recency"])}"

        assert is_binary(c["snippet"])
        assert String.contains?(c["snippet"], "specific snippet body")

        {:ok, context}
      end
    end
  end
end
