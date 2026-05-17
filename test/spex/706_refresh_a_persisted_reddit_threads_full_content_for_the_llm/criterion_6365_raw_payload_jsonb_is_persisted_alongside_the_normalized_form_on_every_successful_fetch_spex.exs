defmodule MarketMySpecSpex.Story706.Criterion6365Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6365 — raw_payload (jsonb) is persisted alongside the
  normalized form on every successful fetch.

  After a successful get_thread call, the response Thread carries both
  the normalized comment_tree AND the raw_payload (Reddit's original
  array-of-two-listings JSON). Both fields are observable in the
  response envelope — no Repo access needed in the assertion.

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

  spex "raw_payload is persisted alongside the normalized form on every successful fetch" do
    scenario "response Thread carries both raw_payload and comment_tree non-empty" do
      given_ "a Thread cassette with a known post + one comment", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "raw001"})

        RedditHelpers.build_comments_cassette!("crit_6365_raw",
          source_thread_id: "raw001",
          post: %{"title" => "Raw payload probe", "selftext" => "OP body raw"},
          comments: [%{id: "rc1", body: "A comment", author: "u1", score: 5}]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6365_raw", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the Thread carries raw_payload AND comment_tree, both non-empty", context do
        thread = context.payload["thread"] || context.payload

        assert thread["raw_payload"] != nil and thread["raw_payload"] != %{},
               "expected raw_payload non-empty, got: #{inspect(thread["raw_payload"])}"

        # raw_payload should contain Reddit's array shape OR a map encoding it
        assert is_list(thread["raw_payload"]) or is_map(thread["raw_payload"]),
               "expected raw_payload to be a list (Reddit's [post, comments] shape) or a map wrapping it"

        comment_tree = thread["comment_tree"]
        children =
          cond do
            is_list(comment_tree) -> comment_tree
            is_map(comment_tree) -> Map.get(comment_tree, "children", [])
            true -> []
          end

        refute Enum.empty?(children),
               "expected comment_tree to be non-empty (cassette returned 1 comment)"

        {:ok, context}
      end
    end
  end
end
