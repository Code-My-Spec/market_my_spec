defmodule MarketMySpecSpex.Story706.Criterion6371Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6371 — Platform errors (HTTP 429, 5xx, network failure)
  surface as a usable error response; the persisted Thread row's
  existing data is preserved (no destructive write on failure).

  Pre-seeded Thread has populated content. Cassette returns 429. Response
  carries the cached data (op_body, comment_tree intact) plus a
  stale_warning flag. No fields are wiped, no exception raised.

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

  spex "Platform error preserves persisted data; surfaces as usable error" do
    scenario "Pre-seeded Thread; cassette returns 429; persisted data preserved" do
      given_ "a Thread with populated content (10min old) and a 429 cassette",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        stale = DateTime.utc_now() |> DateTime.add(-600) |> DateTime.truncate(:second)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "err001",
            fetched_at: stale,
            op_body: "Pre-existing op body",
            comment_tree: %{
              "children" => [
                %{"author" => "old_user", "body" => "Pre-existing comment", "score" => 5,
                  "created_utc" => 1_700_000_000.0, "depth" => 0}
              ]
            }
          })

        RedditHelpers.build_comments_cassette!("crit_6371_429",
          source_thread_id: "err001",
          status: 429
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent calls get_thread; cassette returns 429", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6371_429", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "response carries the persisted data + stale_warning; no destructive write",
            context do
        thread = context.payload["thread"] || context.payload

        # Pre-existing op_body and comment_tree must be preserved
        assert thread["op_body"] == "Pre-existing op body",
               "expected op_body preserved on failure, got: #{inspect(thread["op_body"])}"

        comment_tree = thread["comment_tree"]
        children =
          cond do
            is_list(comment_tree) -> comment_tree
            is_map(comment_tree) -> Map.get(comment_tree, "children", [])
            true -> []
          end

        refute Enum.empty?(children),
               "expected pre-existing comment_tree preserved on failure (got empty)"

        # Response should carry a stale_warning indicating refresh failed
        warning = context.payload["stale_warning"] || thread["stale_warning"]
        assert warning != nil,
               "expected stale_warning in response on failed refresh, got: #{inspect(context.payload)}"

        {:ok, context}
      end
    end
  end
end
