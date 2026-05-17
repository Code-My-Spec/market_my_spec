defmodule MarketMySpecSpex.Story706.Criterion6375Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6375 — Agent calls get_thread on a never-deep-read Thread;
  full content is fetched and returned.

  Sister to 6363; this one pins the never-deep-read starting state more
  explicitly: op_body nil, comment_tree empty, raw_payload empty,
  last_activity_at nil, fetched_at nil. After the call, all five fields
  populated.

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

  spex "Agent calls get_thread on a never-deep-read Thread; full content fetched" do
    scenario "Pre-seeded Thread with all detail fields empty → full content after call" do
      given_ "a Thread with op_body nil, comment_tree empty, fetched_at nil",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "never001",
            op_body: nil,
            comment_tree: %{},
            raw_payload: %{},
            fetched_at: nil
          })

        RedditHelpers.build_comments_cassette!("crit_6375_never",
          source_thread_id: "never001",
          post: %{
            "title" => "Never-deep-read",
            "selftext" => "Op body from cassette",
            "score" => 17
          },
          comments: [
            %{id: "fn1", body: "Comment 1", author: "u1", score: 2},
            %{id: "fn2", body: "Comment 2", author: "u2", score: 1}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6375_never", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "all five fields populated post-call", context do
        thread = context.payload["thread"] || context.payload

        assert thread["id"] == context.thread.id

        assert is_binary(thread["op_body"]) and thread["op_body"] != "",
               "expected op_body populated, got: #{inspect(thread["op_body"])}"

        comment_tree = thread["comment_tree"]
        children =
          cond do
            is_list(comment_tree) -> comment_tree
            is_map(comment_tree) -> Map.get(comment_tree, "children", [])
            true -> []
          end

        refute Enum.empty?(children),
               "expected non-empty comment_tree, got: #{inspect(comment_tree)}"

        assert thread["raw_payload"] != nil and thread["raw_payload"] != %{}
        assert thread["fetched_at"] != nil
        assert thread["last_activity_at"] != nil

        {:ok, context}
      end
    end
  end
end
