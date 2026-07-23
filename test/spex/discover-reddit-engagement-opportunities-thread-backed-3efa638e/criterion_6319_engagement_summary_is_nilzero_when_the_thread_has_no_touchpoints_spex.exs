defmodule MarketMySpecSpex.Story705.Criterion6319Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6319 — Engagement summary is nil/zero when the Thread has
  no Touchpoints.

  Threads surfaced by search start with zero touchpoints. The engagement
  summary in their candidate response must be: count = 0, latest_state =
  nil, latest_angle = nil, latest_posted_at = nil. This is the cold-start
  shape the agent sees for a brand-new candidate.

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

  spex "engagement summary is zeroed when no Touchpoints exist on the Thread" do
    scenario "fresh threads from a first-ever scan have engagement: count=0, all latest_* fields nil" do
      given_ "an account with one enabled r/elixir venue and two fresh threads (no touchpoints)",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", enabled: true
        })

        RedditHelpers.build_search_cassette!("crit_6319_no_touch",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Fresh A", score: 1, num_comments: 0, id: "fra",
              permalink: "/r/elixir/comments/fra/_/"},
            %{title: "Fresh B", score: 2, num_comments: 0, id: "frb",
              permalink: "/r/elixir/comments/frb/_/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6319_no_touch", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "every candidate's engagement is %{count: 0, latest_state: nil, latest_angle: nil, latest_posted_at: nil}",
            context do
        candidates = context.payload["candidates"]

        refute Enum.empty?(candidates),
               "expected non-empty candidate list (cassette has 2 fresh threads)"

        assert length(candidates) == 2,
               "expected exactly 2 fresh candidates, got #{length(candidates)}"

        for c <- candidates do
          engagement = c["engagement"]

          assert engagement["count"] == 0,
                 "expected engagement.count=0 for a fresh thread, got #{inspect(engagement)}"

          assert engagement["latest_state"] in [nil],
                 "expected latest_state nil for fresh thread, got #{inspect(engagement["latest_state"])}"

          assert engagement["latest_angle"] in [nil],
                 "expected latest_angle nil, got #{inspect(engagement["latest_angle"])}"

          assert engagement["latest_posted_at"] in [nil],
                 "expected latest_posted_at nil, got #{inspect(engagement["latest_posted_at"])}"
        end

        {:ok, context}
      end
    end
  end
end
