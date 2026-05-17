defmodule MarketMySpecSpex.Story706.Criterion6379Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6379 — Thread with 40 top-level comments returns 25 plus a
  cursor for the rest.

  Sister to 6370; pinned via Three Amigos scenario. Cassette returns
  40 top-level comments. Response carries 25 + non-nil comments_cursor.
  Second call with the cursor returns the remaining 15 + nil cursor.

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

  spex "40-comment thread returns 25 + cursor; cursor fetches the remaining 15" do
    scenario "Pagination across two pages: 25 then 15" do
      given_ "a Thread cassette with 25 page-1 comments + cursor, and 15 page-2 comments + nil cursor",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "page40_001"})

        page1 = for i <- 1..25, do: %{id: "p1c#{i}", body: "Comment #{i}", author: "u#{i}", score: 30 - i}
        page2 = for i <- 26..40, do: %{id: "p2c#{i}", body: "Comment #{i}", author: "u#{i}", score: 30 - i}

        RedditHelpers.build_multi_comments_cassette!("crit_6379_pagination", [
          [
            source_thread_id: "page40_001",
            after: nil,
            post: %{"title" => "Long thread"},
            comments: page1
          ],
          [
            source_thread_id: "page40_001",
            after: "t1_p1c25",
            post: %{"title" => "Long thread"},
            comments: page2
          ]
        ])

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls get_thread; then calls again with the cursor", context do
        {p1, p2} =
          RedditHelpers.with_reddit_cassette("crit_6379_pagination", fn ->
            {:reply, r1, _f1} = GetThread.execute(%{thread_id: context.thread.id}, context.frame)
            page1 = decode_payload(r1)

            cursor = page1["comments_cursor"] || Map.get(page1["thread"] || %{}, "comments_cursor")

            {:reply, r2, _f2} =
              GetThread.execute(
                %{thread_id: context.thread.id, comments_cursor: cursor},
                context.frame
              )

            {page1, decode_payload(r2)}
          end)

        {:ok, Map.merge(context, %{page1: p1, page2: p2})}
      end

      then_ "page 1: 25 comments + non-nil cursor; page 2: 15 comments + nil cursor", context do
        p1_thread = context.page1["thread"] || context.page1
        p2_thread = context.page2["thread"] || context.page2

        p1_top = top_level(p1_thread["comment_tree"])
        p2_top = top_level(p2_thread["comment_tree"])

        assert length(p1_top) == 25,
               "expected 25 top-level comments on page 1, got #{length(p1_top)}"

        p1_cursor = context.page1["comments_cursor"] || p1_thread["comments_cursor"]
        assert p1_cursor != nil and p1_cursor != "",
               "expected non-nil comments_cursor on page 1, got: #{inspect(p1_cursor)}"

        assert length(p2_top) == 15,
               "expected 15 top-level comments on page 2, got #{length(p2_top)}"

        p2_cursor = context.page2["comments_cursor"] || p2_thread["comments_cursor"]
        assert p2_cursor in [nil, ""],
               "expected nil comments_cursor on page 2 (end of listing), got: #{inspect(p2_cursor)}"

        {:ok, context}
      end
    end
  end
end
