defmodule MarketMySpecSpex.Story705.Criterion6349Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6349 — Higher-weight venue's candidate ranks first; repeat
  calls return identical UUIDs and ordering.

  Composite of 6326 (weight ranking) + 6325 (determinism). Two venues
  at different weights; same per-source signal. First run: heavy-weight
  candidate ranks first. Second run with same inputs: identical thread_id
  UUIDs in identical order.

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

  spex "higher-weight venue ranks first; repeat returns identical UUIDs+ordering" do
    scenario "weight 2.0 outranks weight 1.0; second run is byte-identical" do
      given_ "two venues at weights 2.0 and 1.0 with identical-signal candidates",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "elixir", weight: 2.0, enabled: true
        })

        Fixtures.venue_fixture(scope, %{
          source: :reddit, identifier: "programming", weight: 1.0, enabled: true
        })

        RedditHelpers.build_multi_cassette!("crit_6349_combo", [
          [
            subreddit: "elixir",
            query: "elixir",
            children: [
              %{title: "Heavy", score: 10, num_comments: 2, id: "h6349",
                permalink: "/r/elixir/comments/h6349/heavy/"}
            ]
          ],
          [
            subreddit: "programming",
            query: "elixir",
            children: [
              %{title: "Light", score: 10, num_comments: 2, id: "l6349",
                permalink: "/r/programming/comments/l6349/light/"}
            ]
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search is called twice with the same inputs", context do
        run = fn ->
          {:reply, response, _frame} =
            RedditHelpers.with_reddit_cassette("crit_6349_combo", fn ->
              SearchEngagements.execute(%{query: "elixir"}, context.frame)
            end)

          decode_payload(response)
        end

        first = run.()
        second = run.()
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "heavy ranks first; second run has identical thread_id UUIDs in identical order",
            context do
        [first1, second1] = context.first["candidates"]
        assert first1["title"] == "Heavy"
        assert second1["title"] == "Light"

        first_ids = Enum.map(context.first["candidates"], & &1["thread_id"])
        second_ids = Enum.map(context.second["candidates"], & &1["thread_id"])

        assert first_ids == second_ids,
               "expected identical UUIDs+ordering across runs, got #{inspect(first_ids)} vs #{inspect(second_ids)}"

        {:ok, context}
      end
    end
  end
end
