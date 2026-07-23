defmodule MarketMySpecSpex.Story705.Criterion6325Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6325 — Repeat calls with the same query and unchanged
  venues return identical results (same UUIDs).

  Two back-to-back calls with the same query, same venue, same cassette.
  Candidate UUIDs must match across calls (proof the same persisted
  Thread rows were reused, not duplicated). Plus the candidate lists
  must be field-equal.

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

  spex "repeat calls with same query+venues return identical UUIDs and ordering" do
    scenario "two back-to-back calls produce identical candidate lists" do
      given_ "an enabled r/elixir venue and a cassette with 2 deterministic threads",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6325_determ",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "First", score: 5, num_comments: 1, id: "d1",
              permalink: "/r/elixir/comments/d1/first/"},
            %{title: "Second", score: 4, num_comments: 2, id: "d2",
              permalink: "/r/elixir/comments/d2/second/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called twice with the same query", context do
        run = fn ->
          {:reply, response, _frame} =
            RedditHelpers.with_reddit_cassette("crit_6325_determ", fn ->
              SearchEngagements.execute(%{query: "elixir"}, context.frame)
            end)

          decode_payload(response)
        end

        first = run.()
        second = run.()
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "both calls produce non-empty, identical candidate lists with identical UUIDs",
            context do
        refute Enum.empty?(context.first["candidates"]),
               "expected non-empty candidate list (cassette has 2 threads)"

        assert length(context.first["candidates"]) == 2

        first_ids = Enum.map(context.first["candidates"], & &1["thread_id"])
        second_ids = Enum.map(context.second["candidates"], & &1["thread_id"])

        assert first_ids == second_ids,
               "expected identical thread_id UUIDs across calls, got #{inspect(first_ids)} vs #{inspect(second_ids)}"

        assert context.first["candidates"] == context.second["candidates"],
               "expected identical candidate lists across calls"

        {:ok, context}
      end
    end
  end
end
