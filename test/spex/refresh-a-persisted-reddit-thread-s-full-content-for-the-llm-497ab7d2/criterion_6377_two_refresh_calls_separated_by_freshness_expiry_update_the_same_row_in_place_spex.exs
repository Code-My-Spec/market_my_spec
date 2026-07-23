defmodule MarketMySpecSpex.Story706.Criterion6377Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6377 — Two refresh calls separated by freshness expiry
  update the same row in place.

  Sister to 6369; pinned via Three Amigos scenario. Pre-seed a Thread
  with fetched_at far enough in the past that any refresh would update
  it. Run get_thread; cassette returns content. UUID is unchanged
  pre/post.

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

  spex "Two refresh calls (across freshness boundary) update the same Thread row" do
    scenario "Pre-seeded Thread with stale fetched_at; refresh updates in place; UUID stable" do
      given_ "a Thread fetched 1 hour ago with populated content and a cassette returning updated content",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        stale = DateTime.utc_now() |> DateTime.add(-3_600) |> DateTime.truncate(:second)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "twocall001",
            fetched_at: stale,
            op_body: "Stale op body v1",
            comment_tree: %{"children" => []}
          })

        RedditHelpers.build_comments_cassette!("crit_6377_twocall",
          source_thread_id: "twocall001",
          post: %{"title" => "Refreshed", "selftext" => "Op body v2"},
          comments: [%{id: "tc1", body: "Fresh comment", author: "u1", score: 1}]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), original_id: thread.id})}
      end

      when_ "agent calls get_thread outside the freshness window", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6377_twocall", fn ->
            GetThread.execute(%{thread_id: context.original_id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the response Thread has the SAME UUID with refreshed content", context do
        thread = context.payload["thread"] || context.payload

        assert thread["id"] == context.original_id,
               "expected UUID stability post-refresh, got: #{inspect(thread["id"])}"

        assert thread["op_body"] == "Op body v2",
               "expected op_body refreshed, got: #{inspect(thread["op_body"])}"

        {:ok, context}
      end
    end
  end
end
