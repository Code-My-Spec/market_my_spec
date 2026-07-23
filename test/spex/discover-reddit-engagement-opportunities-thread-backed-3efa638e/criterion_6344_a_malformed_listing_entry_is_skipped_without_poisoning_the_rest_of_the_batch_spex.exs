defmodule MarketMySpecSpex.Story705.Criterion6344Spex do
  @moduledoc """
  Story 705 — Discover Reddit engagement opportunities (Thread-backed)
  Criterion 6344 — A malformed listing entry is skipped without
  poisoning the rest of the batch.

  Reddit cassette returns three entries; the middle one is missing
  source_thread_id (malformed). The orchestrator persists the two valid
  Threads and silently drops the malformed entry. No exception, no
  per-venue failure entry (record-level rejection, not venue-level).

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

  spex "a malformed listing entry is silently skipped; valid entries land" do
    scenario "three entries returned; middle one missing source_thread_id; two persist" do
      given_ "a cassette returning three children, the middle one missing id",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        RedditHelpers.build_search_cassette!("crit_6344_malformed",
          subreddit: "elixir",
          query: "elixir",
          children: [
            %{title: "Valid 1", score: 5, num_comments: 1, id: "v1",
              permalink: "/r/elixir/comments/v1/valid1/"},
            %{title: "Missing id", score: 3, num_comments: 0, id: nil,
              permalink: "/r/elixir/comments/missing/_/"},
            %{title: "Valid 2", score: 7, num_comments: 2, id: "v2",
              permalink: "/r/elixir/comments/v2/valid2/"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6344_malformed", fn ->
            SearchEngagements.execute(%{query: "elixir"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "two valid candidates appear; malformed one is silently dropped; no failure entry",
            context do
        candidates = context.payload["candidates"]
        failures = context.payload["failures"]

        titles = Enum.map(candidates, & &1["title"]) |> Enum.sort()
        assert titles == ["Valid 1", "Valid 2"],
               "expected only the two valid candidates, got titles: #{inspect(titles)}"

        assert failures == [],
               "expected no per-venue failure entry for a record-level skip, got: #{inspect(failures)}"

        {:ok, context}
      end
    end
  end
end
