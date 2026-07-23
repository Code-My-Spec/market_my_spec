defmodule MarketMySpecSpex.Story705.Criterion6347Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6347 — One venue rate-limited; healthy venue's candidates
  still surface.

  Sister criterion to 6321; pinned separately. Two venues, one returns
  429, the other returns a thread. Response carries the survivor +
  failure entry for the 429 venue.

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

  spex "one venue rate-limited; healthy venue's candidates still surface" do
    scenario "Reddit 429 on one venue; survivor returns + failure listed" do
      given_ "two enabled venues; one returns 200, other returns 429",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming", enabled: true})

        RedditHelpers.build_multi_cassette!("crit_6347_rl", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Healthy", score: 5, num_comments: 1, id: "h1",
                permalink: "/r/elixir/comments/h1/_/"}
            ]
          ],
          [
            subreddit: "programming",
            query: "elixir",
            status: 429
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6347_rl", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "healthy candidate appears; one failure entry recorded", context do
        candidates = context.payload["candidates"]
        failures = context.payload["failures"]

        assert length(candidates) == 1
        [c] = candidates
        assert c["title"] == "Healthy"

        refute Enum.empty?(failures),
               "expected at least one failure entry for the 429 venue"

        {:ok, context}
      end
    end
  end
end
