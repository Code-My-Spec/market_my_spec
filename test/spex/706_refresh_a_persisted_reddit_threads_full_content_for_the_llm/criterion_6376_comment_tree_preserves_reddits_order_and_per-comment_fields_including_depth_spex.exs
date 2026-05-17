defmodule MarketMySpecSpex.Story706.Criterion6376Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6376 — comment_tree preserves Reddit's order and per-comment
  fields including depth.

  Sister to 6364; pinned separately. Three top-level comments in
  Reddit's order; one has a nested reply that itself has a reply (depth
  2). Every comment in the tree carries author/body/score/created_utc/
  depth with depth correctly assigned per nesting level.

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

  spex "comment_tree preserves Reddit's order + per-comment fields including depth" do
    scenario "Three top-level comments with a 2-level-deep reply chain; all fields present" do
      given_ "a cassette with 3 top-level comments and a depth-2 reply chain",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "depth001"})

        RedditHelpers.build_comments_cassette!("crit_6376_depth",
          source_thread_id: "depth001",
          post: %{"title" => "Depth probe"},
          comments: [
            %{id: "T1", body: "Top 1", author: "u1", score: 10},
            %{id: "T2", body: "Top 2", author: "u2", score: 5,
              replies: [
                %{id: "R1", body: "Depth 1 reply", author: "u3", score: 3,
                  replies: [
                    %{id: "R2", body: "Depth 2 reply", author: "u4", score: 1}
                  ]
                }
              ]
            },
            %{id: "T3", body: "Top 3", author: "u5", score: 2}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6376_depth", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "top-level order matches Reddit; depths 0, 1, 2 assigned correctly", context do
        thread = context.payload["thread"] || context.payload
        tree = top_level(thread["comment_tree"])

        assert length(tree) == 3, "expected 3 top-level comments, got #{length(tree)}"

        bodies_top = Enum.map(tree, &Map.get(&1, "body"))
        assert bodies_top == ["Top 1", "Top 2", "Top 3"],
               "expected top-level order [Top 1, Top 2, Top 3], got #{inspect(bodies_top)}"

        for entry <- tree do
          assert entry["depth"] == 0, "expected top-level depth=0, got: #{inspect(entry)}"

          for key <- ~w(author body score created_utc depth) do
            assert Map.has_key?(entry, key),
                   "expected '#{key}' on every comment, got: #{inspect(Map.keys(entry))}"
          end
        end

        t2 = Enum.at(tree, 1)
        r1_list = top_level(Map.get(t2, "replies", []))
        assert length(r1_list) == 1
        r1 = hd(r1_list)
        assert r1["body"] == "Depth 1 reply"
        assert r1["depth"] == 1

        r2_list = top_level(Map.get(r1, "replies", []))
        assert length(r2_list) == 1
        r2 = hd(r2_list)
        assert r2["body"] == "Depth 2 reply"
        assert r2["depth"] == 2

        {:ok, context}
      end
    end
  end
end
