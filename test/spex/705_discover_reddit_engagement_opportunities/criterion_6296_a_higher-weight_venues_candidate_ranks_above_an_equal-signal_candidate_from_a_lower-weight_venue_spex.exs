defmodule MarketMySpecSpex.Story705.Criterion6296Spex do
  @moduledoc """
  Story 705 — Criterion 6296 — A higher-weight venue's candidate ranks
  above an equal-signal candidate from a lower-weight venue.

  Two venues with the same identifier-flavored content but different
  weights: r/elixir (weight 2.0) and r/programming (weight 1.0). Each
  returns one thread with the SAME score and num_comments. The orchestrator
  ranks by `weight * signal` desc, so the r/elixir candidate must appear
  first.
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

  spex "higher-weight venue's candidate ranks above an equal-signal candidate" do
    scenario "weight 2.0 venue's candidate appears before weight 1.0 with identical signal" do
      given_ "two venues weighted 2.0 and 1.0, each returning one thread with the same signal",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", weight: 2.0, enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "programming", weight: 1.0, enabled: true
        })

        common = [score: 10, num_comments: 2]

        RedditHelpers.build_multi_cassette!("crit_6296_weight", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Heavy venue",
                score: common[:score], num_comments: common[:num_comments],
                id: "h1", permalink: "/r/elixir/comments/h1/heavy/"}
            ]
          ],
          [
            subreddit: "programming",
            query: "elixir",
            children: [
              %{title: "Light venue",
                score: common[:score], num_comments: common[:num_comments],
                id: "l1", permalink: "/r/programming/comments/l1/light/"}
            ]
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6296_weight", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode(response))}
      end

      then_ "the heavy venue's candidate ranks first", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 2
        [first, second] = candidates
        assert first["title"] == "Heavy venue",
               "expected weight 2.0 venue's candidate first, got: #{inspect(Enum.map(candidates, & &1["title"]))}"
        assert second["title"] == "Light venue"

        {:ok, context}
      end
    end
  end
end
