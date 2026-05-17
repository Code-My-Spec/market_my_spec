defmodule MarketMySpecSpex.Story705.Criterion6321Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6321 — A failing source (rate limit, network, auth) degrades
  gracefully — other sources still return results and the failure is
  reported in the response.

  Two enabled Reddit venues; one returns 429 (rate limit), the other
  returns a thread. The response carries the surviving thread AND a
  failure entry referencing the rate-limited venue. No exception.

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

  spex "one venue rate-limited; healthy venue still returns and failure listed" do
    scenario "Reddit 429 on one venue; other venue returns; envelope has both" do
      given_ "two enabled Reddit venues with mixed cassette responses (200 + 429)",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "programming", enabled: true})

        RedditHelpers.build_multi_cassette!("crit_6321_failover", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Survivor", score: 5, num_comments: 1, id: "s1",
                permalink: "/r/elixir/comments/s1/survivor/"}
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
          RedditHelpers.with_reddit_cassette("crit_6321_failover", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "envelope carries surviving candidate and a failure entry", context do
        candidates = context.payload["candidates"]
        failures = context.payload["failures"]

        assert length(candidates) == 1,
               "expected 1 surviving candidate, got #{length(candidates)}"

        [survivor] = candidates
        assert survivor["title"] == "Survivor"

        refute Enum.empty?(failures),
               "expected at least one failure entry for the 429 venue"

        {:ok, context}
      end
    end
  end
end
