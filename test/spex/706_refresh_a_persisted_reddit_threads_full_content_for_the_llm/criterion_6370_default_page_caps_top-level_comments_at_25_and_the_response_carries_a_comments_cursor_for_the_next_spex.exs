defmodule MarketMySpecSpex.Story706.Criterion6370Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6370 — Default page caps top-level comments at 25 and the
  response carries a comments_cursor for the next page.

  Cassette returns 40 top-level comments. The response carries exactly
  25 entries in comment_tree at the top level plus a non-nil
  comments_cursor token. Subsequent page tested in 6379.

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

  spex "first page caps top-level comments at 25 plus a comments_cursor" do
    scenario "Cassette with 40 top-level comments returns 25 + cursor" do
      given_ "a Thread cassette with 40 top-level comments", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "cap001"})

        many_comments =
          for i <- 1..40 do
            %{id: "cm#{i}", body: "Comment #{i}", author: "u#{i}", score: 40 - i}
          end

        RedditHelpers.build_comments_cassette!("crit_6370_cap",
          source_thread_id: "cap001",
          post: %{"title" => "Many-comments thread"},
          comments: many_comments
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6370_cap", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "exactly 25 top-level comments and a non-nil comments_cursor", context do
        thread = context.payload["thread"] || context.payload
        comment_tree = thread["comment_tree"]

        children =
          cond do
            is_list(comment_tree) -> comment_tree
            is_map(comment_tree) -> Map.get(comment_tree, "children", [])
            true -> []
          end

        assert length(children) == 25,
               "expected exactly 25 top-level comments, got #{length(children)}"

        cursor = context.payload["comments_cursor"] || thread["comments_cursor"]
        assert cursor != nil and cursor != "",
               "expected a non-nil comments_cursor, got: #{inspect(cursor)}"

        {:ok, context}
      end
    end
  end
end
