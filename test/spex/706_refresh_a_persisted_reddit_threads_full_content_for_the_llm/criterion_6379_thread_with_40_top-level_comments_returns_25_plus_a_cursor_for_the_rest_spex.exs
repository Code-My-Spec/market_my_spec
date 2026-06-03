defmodule MarketMySpecSpex.Story706.Criterion6379Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6379 — Thread with more than 25 comments returns the first 25.

  Sister to 6370; pinned via Three Amigos scenario. Reddit's Atom (RSS)
  feed honors `?limit=` but exposes NO comment cursor, so a 40-comment
  thread returns the first 25 with a nil comments_cursor — there is no
  second page to fetch.

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

  defp top_level(comment_tree) do
    cond do
      is_list(comment_tree) -> comment_tree
      is_map(comment_tree) -> Map.get(comment_tree, "children", [])
      true -> []
    end
  end

  spex "thread with more than 25 comments returns the first 25, no comment cursor" do
    scenario "A 40-comment thread returns the first 25 with a nil comments_cursor" do
      given_ "a Thread cassette with 40 comments", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "page40_001"})

        comments =
          for i <- 1..40, do: %{id: "c#{i}", body: "Comment #{i}", author: "u#{i}", score: 30 - i}

        RedditHelpers.build_comments_cassette!("crit_6379_cap",
          source_thread_id: "page40_001",
          post: %{"title" => "Long thread"},
          comments: comments
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6379_cap", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "25 comments are returned and comments_cursor is nil (no second page)", context do
        thread = context.payload["thread"] || context.payload
        top = top_level(thread["comment_tree"])

        assert length(top) == 25,
               "expected 25 comments (capped at the limit), got #{length(top)}"

        # RSS exposes no comment cursor — there is no remaining page to fetch.
        cursor = context.payload["comments_cursor"] || thread["comments_cursor"]
        assert cursor in [nil, ""],
               "expected nil comments_cursor (RSS has no comment pagination), got: #{inspect(cursor)}"

        {:ok, context}
      end
    end
  end
end
