defmodule MarketMySpecSpex.Story706.Criterion6368Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6368 — Within the 5-minute freshness window, a repeat
  get_thread on the same UUID returns the cached row without an HTTP
  call to Reddit.

  Pre-seed a Thread with fetched_at = 30 seconds ago (well within the
  5-minute window). Cassette has NO recorded interactions. Calling
  get_thread should NOT raise a ReqCassette mismatch (because no HTTP
  call is made) — the response is the cached Thread.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
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

  spex "Within 5min window: repeat get_thread returns cached row, no HTTP call" do
    scenario "Pre-seeded Thread with fetched_at 30s ago; cassette has zero interactions" do
      given_ "a Thread fetched 30 seconds ago with op_body+comment_tree already populated; cassette is empty",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        recent = DateTime.utc_now() |> DateTime.add(-30) |> DateTime.truncate(:second)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "cache001",
            fetched_at: recent,
            op_body: "Cached op body",
            comment_tree: %{
              "children" => [
                %{"author" => "u1", "body" => "Cached comment", "score" => 1,
                  "created_utc" => 1_700_000_000.0, "depth" => 0}
              ]
            }
          })

        # Empty cassette — zero interactions. Any HTTP call would raise.
        RedditHelpers.build_comments_cassette!("crit_6368_empty",
          source_thread_id: "__never_used__",
          post: %{}, comments: []
        )

        # Override the cassette to truly have zero interactions
        empty_cassette = %{"version" => "1.0", "interactions" => []}
        File.write!("test/cassettes/reddit/crit_6368_cache.json", Jason.encode!(empty_cassette))
        ExUnit.Callbacks.on_exit(fn -> File.rm("test/cassettes/reddit/crit_6368_cache.json") end)

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread, recent: recent})}
      end

      when_ "the agent calls get_thread within the window", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6368_cache", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the response is the cached Thread; no exception was raised", context do
        thread = context.payload["thread"] || context.payload

        assert thread["id"] == context.thread.id
        assert thread["op_body"] == "Cached op body",
               "expected cached op_body unchanged, got: #{inspect(thread["op_body"])}"

        # Verify fetched_at unchanged (still ~30s ago, not updated to "now")
        # If the impl re-fetched and updated, fetched_at would be ~now
        case thread["fetched_at"] do
          fetched when is_binary(fetched) ->
            {:ok, parsed, _} = DateTime.from_iso8601(fetched)
            diff = DateTime.diff(DateTime.utc_now(), parsed, :second)

            assert diff >= 25,
                   "expected fetched_at to remain ~30s old (cached), but was updated; diff=#{diff}s"

          _ ->
            # fall through — implementation may serialize differently
            :ok
        end

        {:ok, context}
      end
    end
  end
end
