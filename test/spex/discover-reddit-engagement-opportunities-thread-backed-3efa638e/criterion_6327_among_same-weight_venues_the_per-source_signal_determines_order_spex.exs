defmodule MarketMySpecSpex.Story705.Criterion6327Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6327 — Among same-weight venues, the per-source signal
  determines order.

  Two venues with weight 1.0; each returns one thread. Higher-score
  thread ranks above lower-score. Signal = score + 0.5 × num_comments
  per the orchestrator.

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

  spex "same-weight venues: per-source signal determines order" do
    scenario "score=50 thread ranks above score=5 thread when weights are equal" do
      given_ "two same-weight venues; one high-score thread, one low-score thread",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", weight: 1.0, enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "programming", weight: 1.0, enabled: true
        })

        RedditHelpers.build_multi_cassette!("crit_6327_signal", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Hot", score: 50, num_comments: 10, id: "h2",
                permalink: "/r/elixir/comments/h2/hot/"}
            ]
          ],
          [
            subreddit: "programming",
            query: "elixir",
            children: [
              %{title: "Cold", score: 5, num_comments: 1, id: "c2",
                permalink: "/r/programming/comments/c2/cold/"}
            ]
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6327_signal", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "higher-score candidate ranks first", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 2
        [first, second] = candidates
        assert first["title"] == "Hot"
        assert second["title"] == "Cold"

        {:ok, context}
      end
    end
  end
end
