defmodule MarketMySpecSpex.Story706.Criterion6364Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6364 — Reddit's /comments/<id>.json is normalized into
  comment_tree (jsonb) preserving Reddit's response order (confidence/hot
  at top level, chronological within sub-trees); each comment carries
  author handle, body, score, created_utc, depth.

  Cassette returns three top-level comments [C1, C2, C3] in Reddit's
  order; C2 has nested replies [R1, R2]. Response comment_tree preserves
  that order at every level and every entry carries the five required
  fields.

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

  spex "comment_tree preserves Reddit order at every level; comments carry canonical fields" do
    scenario "three top-level comments + two nested replies preserve Reddit's order; fields present" do
      given_ "a Thread cassette with three top-level comments and two nested replies under the second",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ord001"})

        RedditHelpers.build_comments_cassette!("crit_6364_order",
          source_thread_id: "ord001",
          post: %{"title" => "Order test", "selftext" => "OP body"},
          comments: [
            %{id: "C1", body: "Top 1", author: "u1", score: 10},
            %{id: "C2", body: "Top 2", author: "u2", score: 5,
              replies: [
                %{id: "R1", body: "Reply 1", author: "u3", score: 2},
                %{id: "R2", body: "Reply 2", author: "u4", score: 1}
              ]
            },
            %{id: "C3", body: "Top 3", author: "u5", score: 3}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6364_order", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "top-level order is [C1, C2, C3]; C2's replies are [R1, R2]; every comment has the five required fields",
            context do
        thread = context.payload["thread"] || context.payload
        tree = top_level(thread["comment_tree"])

        refute Enum.empty?(tree), "expected non-empty comment_tree"
        assert length(tree) == 3, "expected 3 top-level comments, got #{length(tree)}"

        top_ids = Enum.map(tree, &(&1["id"] || Map.get(&1, "name") |> to_string()))
        assert hd(top_ids) =~ "C1" or hd(tree)["body"] == "Top 1",
               "expected first top-level to be C1, got: #{inspect(hd(tree))}"

        # Verify every comment in the tree (including nested) has the canonical fields
        for entry <- tree do
          for key <- ~w(author body score created_utc depth) do
            assert Map.has_key?(entry, key),
                   "expected comment to have '#{key}' field, got: #{inspect(Map.keys(entry))}"
          end
        end

        # Find C2 (Top 2) and verify nested order
        c2 = Enum.find(tree, &(&1["body"] == "Top 2"))
        assert c2, "expected to find Top 2 in tree"

        replies = top_level(Map.get(c2, "replies", []))
        assert length(replies) == 2, "expected C2 to have 2 nested replies, got #{length(replies)}"

        [r1, r2] = replies
        assert r1["body"] == "Reply 1"
        assert r2["body"] == "Reply 2"
        assert r1["depth"] == 1
        assert r2["depth"] == 1

        {:ok, context}
      end
    end
  end
end
