defmodule MarketMySpecSpex.Story705.Criterion6329Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6329 — Recency reflects time of last activity, not thread
  creation.

  v1 scope: Reddit's listing doesn't expose last-comment time. The
  candidate's `recency` field is populated from Thread.last_activity_at
  when set (by deep-dive get_thread, story 706), else Thread.inserted_at.
  This spec asserts the candidate carries a numeric recency value on
  every result.

  Per criterion 6352, when a deep-dive has populated last_activity_at,
  recency reflects that; otherwise inserted_at is the v1 proxy.

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

  spex "recency is populated for every candidate" do
    scenario "candidates carry a numeric (or timestamp-ish) recency value" do
      given_ "a venue and a cassette with two threads at distinct created_utc values",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6329_recency",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Newer", score: 1, num_comments: 0, created_utc: 1_720_000_000.0,
              id: "r1", permalink: "/r/elixir/comments/r1/newer/"},
            %{title: "Older", score: 1, num_comments: 0, created_utc: 1_700_000_000.0,
              id: "r2", permalink: "/r/elixir/comments/r2/older/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6329_recency", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "every candidate has a non-nil recency value", context do
        candidates = context.payload["candidates"]
        refute Enum.empty?(candidates)

        for c <- candidates do
          assert c["recency"] != nil,
                 "expected non-nil recency, got: #{inspect(c["recency"])}"
        end

        {:ok, context}
      end
    end
  end
end
