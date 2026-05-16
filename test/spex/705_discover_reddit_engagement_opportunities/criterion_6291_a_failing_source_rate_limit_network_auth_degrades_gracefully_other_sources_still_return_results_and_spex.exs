defmodule MarketMySpecSpex.Story705.Criterion6291Spex do
  @moduledoc """
  Story 705 — Criterion 6291 — A failing source (rate limit, network, auth)
  degrades gracefully — other sources still return results and the failure
  is reported in the response.

  Two enabled venues: r/elixir returns 200 with one thread; r/programming
  returns 429 (rate-limited). The response carries the r/elixir candidate
  AND a per-venue failure entry for r/programming. Per-venue failure does
  not cause the whole search to error.
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

  spex "a failing source degrades gracefully" do
    scenario "one venue returns 429; the other's candidates still surface and failures list the 429" do
      given_ "two enabled venues; one cassette interaction is 200, the other 429",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "programming", enabled: true
        })

        RedditHelpers.build_multi_cassette!("crit_6291_isolation", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Survivor thread", score: 5, num_comments: 1, id: "s1",
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
          RedditHelpers.with_reddit_cassette("crit_6291_isolation", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode(response))}
      end

      then_ "the envelope carries the surviving candidate AND a failure entry", context do
        candidates = context.payload["candidates"]
        failures = context.payload["failures"]

        assert length(candidates) == 1, "expected one surviving candidate, got #{length(candidates)}"
        [survivor] = candidates
        assert survivor["title"] == "Survivor thread"

        assert is_list(failures)
        refute Enum.empty?(failures),
               "expected at least one failure entry for the 429 venue"

        {:ok, context}
      end
    end
  end
end
