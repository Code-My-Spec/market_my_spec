defmodule MarketMySpecSpex.Story705.Criterion6323Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6323 — Search returns only candidates from the calling
  account's venues.

  Two accounts, two venues. Account A's search must surface only A's
  Reddit candidates — B's venue is never queried. Cassette only includes
  A's interaction; a stray B call would raise a ReqCassette mismatch.

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

  spex "search returns only candidates from the caller's account venues" do
    scenario "Account A's call sees only A's Reddit candidates" do
      given_ "two accounts each with their own Reddit venue",
             context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope_a, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope_b, %{source: :reddit, identifier: "programming", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6323_scoped",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Account A thread", score: 4, num_comments: 1, id: "aa1",
              permalink: "/r/elixir/comments/aa1/_/"}
          ]
        )

        {:ok, Map.merge(context, %{frame_a: build_frame(scope_a)})}
      end

      when_ "Account A's frame calls search_engagements", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6323_scoped", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame_a)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "only Account A's venue candidate appears", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 1
        [c] = candidates
        assert c["title"] == "Account A thread"
        assert c["url"] =~ "/r/elixir/"

        {:ok, context}
      end
    end
  end
end
