defmodule MarketMySpecSpex.Story705.Criterion6300Spex do
  @moduledoc """
  Story 705 — Criterion 6300 — First page returns up to 25 candidates per source.

  Single Reddit venue. Cassette serves a listing with 25 threads in
  `data.children`. The adapter's request sets `limit=25` in the query
  string (cassette URL matching enforces this), and the response yields
  exactly 25 candidates.
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

  spex "first page returns up to 25 candidates per source" do
    scenario "cassette with 25 threads yields 25 candidates from a single venue" do
      given_ "a venue and a 25-thread cassette", context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        threads =
          for i <- 1..25 do
            %{
              title: "Thread #{i}",
              score: 26 - i,
              num_comments: i,
              id: "t#{i}",
              permalink: "/r/elixir/comments/t#{i}/_/"
            }
          end

        RedditHelpers.build_search_cassette!("crit_6300_cap",
          subreddit: "elixir",
          query: "elixir",
          children: threads
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6300_cap", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode(response))}
      end

      then_ "the candidate list has exactly 25 entries", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 25,
               "expected 25 candidates from a single venue, got #{length(candidates)}"

        {:ok, context}
      end
    end
  end
end
