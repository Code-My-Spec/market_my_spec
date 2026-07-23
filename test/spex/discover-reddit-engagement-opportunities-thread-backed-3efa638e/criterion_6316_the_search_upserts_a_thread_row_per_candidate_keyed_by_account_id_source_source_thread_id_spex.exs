defmodule MarketMySpecSpex.Story705.Criterion6316Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6316 — The search upserts a Thread row per candidate keyed
  by (account_id, source, source_thread_id) — re-running the same
  search updates the existing row, never duplicates.

  Two runs of the same search against an identical cassette must produce
  the same Thread UUIDs in the response (proving the rows were upserted
  rather than re-created). The agent observes persistence via the stable
  thread_id values — there's no Repo access in the spex.

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

  spex "search upserts Thread rows keyed by (account, source, source_thread_id); repeat runs reuse UUIDs" do
    scenario "two runs of the same cassette produce identical thread_ids across calls" do
      given_ "an account with one enabled r/elixir venue and a cassette with 2 deterministic threads",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{
          source: :reddit,
          identifier: "elixir",
          enabled: true
        })

        RedditHelpers.build_search_cassette!("crit_6316_upsert",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "T1", score: 5, num_comments: 1, id: "ups1",
              permalink: "/r/elixir/comments/ups1/t1/"},
            %{title: "T2", score: 3, num_comments: 0, id: "ups2",
              permalink: "/r/elixir/comments/ups2/t2/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called twice with the same query", context do
        run = fn ->
          {:reply, response, _frame} =
            RedditHelpers.with_reddit_cassette("crit_6316_upsert", fn ->
              SearchEngagements.execute(%{query: "elixir"}, context.frame)
            end)

          decode_payload(response)
        end

        first = run.()
        second = run.()
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "both runs return the same thread_id UUIDs in the same order (proving upsert)",
            context do
        first_ids = Enum.map(context.first["candidates"], & &1["thread_id"])
        second_ids = Enum.map(context.second["candidates"], & &1["thread_id"])

        refute Enum.empty?(first_ids), "expected non-empty thread_ids (cassette has 2 threads)"
        assert length(first_ids) == 2

        assert first_ids == second_ids,
               "expected upsert: same thread_id UUIDs across repeat calls, got #{inspect(first_ids)} vs #{inspect(second_ids)}"

        {:ok, context}
      end
    end
  end
end
