defmodule MarketMySpecSpex.Story705.Criterion6343Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6343 — Re-running the same search updates existing Thread
  rows instead of duplicating them.

  Two scans of the same cassette content; the second scan must return
  the SAME thread_id UUIDs as the first (proving upsert). The candidate
  set is identical across calls.

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

  spex "re-running the same search reuses existing Thread rows (no duplicates)" do
    scenario "two scans of identical cassette content return identical thread_id UUIDs" do
      given_ "an account with one enabled r/elixir venue and a cassette with 2 deterministic threads",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6343_reupsert",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "T-a", score: 5, num_comments: 1, id: "rupa",
              permalink: "/r/elixir/comments/rupa/ta/"},
            %{title: "T-b", score: 3, num_comments: 0, id: "rupb",
              permalink: "/r/elixir/comments/rupb/tb/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "the agent runs the same search twice", context do
        run = fn ->
          {:reply, response, _frame} =
            RedditHelpers.with_reddit_cassette("crit_6343_reupsert", fn ->
              SearchEngagements.execute(%{query: "elixir"}, context.frame)
            end)

          decode_payload(response)
        end

        first = run.()
        second = run.()
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "both runs return the same thread_id UUIDs (rows were upserted, not duplicated)",
            context do
        first_ids = Enum.map(context.first["candidates"], & &1["thread_id"]) |> Enum.sort()
        second_ids = Enum.map(context.second["candidates"], & &1["thread_id"]) |> Enum.sort()

        refute Enum.empty?(first_ids), "expected non-empty result"
        assert length(first_ids) == 2
        assert first_ids == second_ids,
               "expected identical UUIDs across runs, got #{inspect(first_ids)} vs #{inspect(second_ids)}"

        {:ok, context}
      end
    end
  end
end
