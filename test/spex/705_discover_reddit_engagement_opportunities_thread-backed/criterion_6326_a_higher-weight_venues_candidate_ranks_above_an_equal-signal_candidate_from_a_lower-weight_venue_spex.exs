defmodule MarketMySpecSpex.Story705.Criterion6326Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6326 — A higher-weight venue's candidate ranks above an
  equal-signal candidate from a lower-weight venue.

  Two venues at weights 2.0 and 1.0; each returns one candidate with
  identical per-source signal (score, num_comments). The orchestrator
  ranks by weight × signal desc, so the weight-2.0 venue's candidate
  appears first.

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

  spex "higher-weight venue's candidate ranks above equal-signal lower-weight candidate" do
    scenario "weight 2.0 vs weight 1.0, same per-source signal, heavy ranks first" do
      given_ "two venues weighted 2.0 and 1.0; each returns one identical-signal candidate",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", weight: 2.0, enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "programming", weight: 1.0, enabled: true
        })

        RedditHelpers.build_multi_cassette!("crit_6326_weight", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Heavy", score: 10, num_comments: 2, id: "h1",
                permalink: "/r/elixir/comments/h1/heavy/"}
            ]
          ],
          [
            subreddit: "programming",
            query: "elixir",
            children: [
              %{title: "Light", score: 10, num_comments: 2, id: "l1",
                permalink: "/r/programming/comments/l1/light/"}
            ]
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6326_weight", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the heavy venue's candidate ranks first", context do
        candidates = context.payload["candidates"]
        assert length(candidates) == 2
        [first, second] = candidates
        assert first["title"] == "Heavy"
        assert second["title"] == "Light"

        {:ok, context}
      end
    end
  end
end
