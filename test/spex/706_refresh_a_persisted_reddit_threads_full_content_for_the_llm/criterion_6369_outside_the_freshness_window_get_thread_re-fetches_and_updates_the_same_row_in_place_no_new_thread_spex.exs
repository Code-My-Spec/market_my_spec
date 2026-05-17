defmodule MarketMySpecSpex.Story706.Criterion6369Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6369 — Outside the freshness window, get_thread re-fetches
  and updates the same row in place — no new Thread row is created
  (same UUID).

  Pre-seed a Thread with fetched_at = 10 minutes ago (outside the 5-min
  window). Cassette returns new content. The response Thread has the
  same UUID as the pre-seeded row but updated op_body / comment_tree /
  fetched_at.

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

  spex "Outside window: get_thread refreshes in place; UUID unchanged" do
    scenario "Pre-seeded Thread with fetched_at 10min ago; refresh updates same row" do
      given_ "a Thread fetched 10 minutes ago with stale content and a fresh-content cassette",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        stale = DateTime.utc_now() |> DateTime.add(-600) |> DateTime.truncate(:second)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "stale001",
            fetched_at: stale,
            op_body: "Stale op body",
            comment_tree: %{"children" => []}
          })

        RedditHelpers.build_comments_cassette!("crit_6369_outside",
          source_thread_id: "stale001",
          post: %{"title" => "Refreshed", "selftext" => "Fresh op body from cassette"},
          comments: [
            %{id: "fresh_c1", body: "Fresh comment 1", author: "u1", score: 3}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), original_thread: thread})}
      end

      when_ "the agent calls get_thread outside the window", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6369_outside", fn ->
            GetThread.execute(%{thread_id: context.original_thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the response Thread has the same UUID but updated content", context do
        thread = context.payload["thread"] || context.payload

        assert thread["id"] == context.original_thread.id,
               "expected UUID stability (refresh in place), got: #{inspect(thread["id"])} vs #{context.original_thread.id}"

        assert thread["op_body"] == "Fresh op body from cassette",
               "expected op_body updated to cassette content, got: #{inspect(thread["op_body"])}"

        comment_tree = thread["comment_tree"]
        children =
          cond do
            is_list(comment_tree) -> comment_tree
            is_map(comment_tree) -> Map.get(comment_tree, "children", [])
            true -> []
          end

        refute Enum.empty?(children),
               "expected comment_tree updated with cassette content, got empty"

        {:ok, context}
      end
    end
  end
end
