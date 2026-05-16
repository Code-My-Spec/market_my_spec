defmodule MarketMySpecSpex.Story705.Criterion6297Spex do
  @moduledoc """
  Story 705 — Criterion 6297 — Among same-weight venues, the per-source
  signal determines order.

  Two venues with the same weight (1.0). Each returns one thread; the
  high-score thread ranks above the low-score thread. Signal = score +
  0.5 × num_comments (per Engagements.Search.extract_signal/1).
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

  spex "among same-weight venues, per-source signal determines order" do
    scenario "score=50 thread ranks above score=5 thread when both venues weight=1.0" do
      given_ "two same-weight venues, each returning one thread (high score vs low score)",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", weight: 1.0, enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "programming", weight: 1.0, enabled: true
        })

        RedditHelpers.build_multi_cassette!("crit_6297_signal", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Hot thread", score: 50, num_comments: 10, id: "h2",
                permalink: "/r/elixir/comments/h2/hot/"}
            ]
          ],
          [
            subreddit: "programming",
            query: "elixir",
            children: [
              %{title: "Cold thread", score: 5, num_comments: 1, id: "c2",
                permalink: "/r/programming/comments/c2/cold/"}
            ]
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6297_signal", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode(response))}
      end

      then_ "the higher-score candidate ranks first", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 2
        [first, second] = candidates
        assert first["title"] == "Hot thread"
        assert second["title"] == "Cold thread"

        {:ok, context}
      end
    end
  end
end
