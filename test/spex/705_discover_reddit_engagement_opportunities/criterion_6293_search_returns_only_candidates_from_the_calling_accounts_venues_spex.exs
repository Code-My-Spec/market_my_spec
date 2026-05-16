defmodule MarketMySpecSpex.Story705.Criterion6293Spex do
  @moduledoc """
  Story 705 — Criterion 6293 — Search returns only candidates from the
  calling account's venues.

  Two accounts. Each has a different Reddit venue. Calling search_engagements
  with account A's scope only queries A's venue — B's venue is not touched
  (cassette would raise on an unexpected URL).
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

  defp decode(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  spex "search returns only candidates from the calling account's venues" do
    scenario "account A's call sees A's venue; B's venue is not queried" do
      given_ "two accounts; A owns r/elixir, B owns r/programming",
             context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope_a, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope_b, %{source: :reddit, identifier: "programming", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6293_scoped",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Account A thread", score: 4, num_comments: 1, id: "aa1",
              permalink: "/r/elixir/comments/aa1/a/"}
          ]
        )

        {:ok, Map.merge(context, %{frame_a: build_frame(scope_a)})}
      end

      when_ "account A's frame calls search_engagements", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6293_scoped", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame_a)
          end)

        {:ok, Map.put(context, :payload, decode(response))}
      end

      then_ "only A's venue's candidate appears (B's venue was never touched)", context do
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
