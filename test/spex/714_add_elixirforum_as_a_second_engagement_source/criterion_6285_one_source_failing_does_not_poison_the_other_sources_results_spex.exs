defmodule MarketMySpecSpex.Story714.Criterion6285Spex do
  @moduledoc """
  Story 714 — Add ElixirForum as a second engagement source
  Criterion 6285 — One source failing does not poison the other
  source's results.

  Failure isolation: Reddit fails (5xx in recording), ElixirForum
  succeeds — the orchestrator catches the Reddit failure and still
  returns ElixirForum candidates plus a Reddit failure entry.

  Test infrastructure: ReqCassette via `with_mixed_cassette/2`. The
  cassette captures the failure response shape — record once with a
  Reddit endpoint returning 5xx (or a forced rate-limit), then replay.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.ElixirForumHelpers
  alias MarketMySpecSpex.Fixtures

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

  spex "Reddit failure; ElixirForum 200 → forum candidates returned, Reddit failure isolated" do
    scenario "Reddit fails while ElixirForum returns; envelope carries both" do
      given_ "one Reddit venue + one ElixirForum venue", context do
        scope = Fixtures.account_scoped_user_fixture()
        Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir", enabled: true})

        Fixtures.venue_fixture(scope, %{
          source: :elixirforum,
          identifier: "phoenix-forum",
          enabled: true
        })

        {:ok, Map.merge(context, %{frame: build_frame(scope)})}
      end

      when_ "search_engagements is called", context do
        {:reply, resp, _} =
          ElixirForumHelpers.with_mixed_cassette("crit_6285_failure_isolation", fn ->
            SearchEngagements.execute(%{query: "phoenix"}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(resp))}
      end

      then_ "envelope returns the forum candidate AND a Reddit failure entry", context do
        candidates = context.payload["candidates"] || []
        failures = context.payload["failures"] || []

        forum_candidate =
          Enum.find(candidates, fn c -> to_string(c["source"] || c[:source]) == "elixirforum" end)

        assert forum_candidate, "expected ElixirForum candidate to survive Reddit failure"

        reddit_failure =
          Enum.find(failures, fn f -> to_string(f["source"] || f[:source]) == "reddit" end)

        assert reddit_failure, "expected Reddit failure entry; got failures: #{inspect(failures)}"

        assert is_list(candidates)
        assert is_list(failures)

        {:ok, context}
      end
    end
  end
end
