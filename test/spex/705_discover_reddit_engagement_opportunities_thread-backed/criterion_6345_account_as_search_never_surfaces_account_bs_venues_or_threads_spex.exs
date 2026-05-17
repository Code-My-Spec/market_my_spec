defmodule MarketMySpecSpex.Story705.Criterion6345Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6345 — Account A's search never surfaces Account B's venues
  or Threads.

  Two accounts, each with a venue. Account A's search must query only
  A's venue. Cassette is configured with only A's interaction —
  ReqCassette in :replay would raise if B's venue were queried.

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

  spex "Account A's search never queries or surfaces Account B's venues or Threads" do
    scenario "Account A's frame calls search; B's venue is never touched" do
      given_ "two accounts; A owns r/elixir, B owns r/programming; cassette has only r/elixir",
             context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope_a, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope_b, %{source: :reddit, identifier: "programming", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6345_scoped",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "A's thread", score: 4, num_comments: 1, id: "aaa",
              permalink: "/r/elixir/comments/aaa/_/"}
          ]
        )

        {:ok, Map.merge(context, %{frame_a: build_frame(scope_a)})}
      end

      when_ "Account A's frame calls search_engagements", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6345_scoped", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame_a)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "only A's venue candidate appears; no leakage from B", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 1
        [c] = candidates
        assert c["title"] == "A's thread"
        assert c["url"] =~ "/r/elixir/"
        refute c["url"] =~ "/r/programming/"

        {:ok, context}
      end
    end
  end
end
