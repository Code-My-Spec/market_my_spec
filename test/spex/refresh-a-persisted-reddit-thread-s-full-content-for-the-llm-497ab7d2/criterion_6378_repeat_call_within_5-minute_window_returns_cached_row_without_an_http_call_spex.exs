defmodule MarketMySpecSpex.Story706.Criterion6378Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6378 — Repeat call within 5-minute window returns cached
  row without an HTTP call.

  Sister to 6368; pinned via Three Amigos scenario. Pre-seed Thread
  fetched 30s ago; cassette is empty (zero interactions). Calling
  get_thread does not raise (no HTTP call attempted) and returns
  cached content.

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

  spex "Repeat call within 5-min window returns cached row, no HTTP" do
    scenario "Thread with fetched_at 30s ago; cassette zero-interactions; no HTTP raised" do
      given_ "a Thread fetched 30s ago with populated content; cassette empty",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        recent = DateTime.utc_now() |> DateTime.add(-30) |> DateTime.truncate(:second)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "cache6378",
            fetched_at: recent,
            op_body: "Cached payload",
            comment_tree: %{
              "children" => [
                %{"author" => "u1", "body" => "Cached comment", "score" => 1,
                  "created_utc" => 1_700_000_000.0, "depth" => 0}
              ]
            }
          })

        path = "test/cassettes/reddit/crit_6378_window.json"
        File.mkdir_p!("test/cassettes/reddit")
        File.write!(path, Jason.encode!(%{"version" => "1.0", "interactions" => []}))
        ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6378_window", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "cached Thread is returned; no HTTP call was made", context do
        thread = context.payload["thread"] || context.payload

        assert thread["id"] == context.thread.id
        assert thread["op_body"] == "Cached payload",
               "expected cached op_body preserved, got: #{inspect(thread["op_body"])}"

        {:ok, context}
      end
    end
  end
end
