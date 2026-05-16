defmodule MarketMySpecSpex.Story705.Criterion6295Spex do
  @moduledoc """
  Story 705 — Criterion 6295 — Repeat calls with the same query and
  unchanged venues return identical results.

  Single venue, two back-to-back calls with the same query. Cassette
  replays identical responses; candidate lists must be byte-equal.
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

  spex "repeat calls with same query and venues return identical results" do
    scenario "two back-to-back calls produce identical candidate lists" do
      given_ "an enabled r/elixir venue and a cassette with 2 deterministic threads",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6295_determ",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "First", score: 5, num_comments: 1, id: "d1",
              permalink: "/r/elixir/comments/d1/first/"},
            %{title: "Second", score: 4, num_comments: 2, id: "d2",
              permalink: "/r/elixir/comments/d2/second/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called twice with the same query", context do
        run = fn ->
          {:reply, response, _frame} =
            RedditHelpers.with_reddit_cassette("crit_6295_determ", fn ->
              SearchEngagements.execute(%{query: "elixir"}, context.frame)
            end)

          decode(response)
        end

        first = run.()
        second = run.()
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "both calls' candidate lists are non-empty and equal", context do
        refute Enum.empty?(context.first["candidates"]),
               "expected non-empty candidate list (cassette has 2 threads)"

        assert length(context.first["candidates"]) == 2

        assert context.first["candidates"] == context.second["candidates"],
               "expected identical candidate lists across calls"

        {:ok, context}
      end
    end
  end
end
