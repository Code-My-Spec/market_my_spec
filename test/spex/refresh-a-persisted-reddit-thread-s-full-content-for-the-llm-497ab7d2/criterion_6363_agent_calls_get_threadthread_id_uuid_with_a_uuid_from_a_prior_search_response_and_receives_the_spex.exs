defmodule MarketMySpecSpex.Story706.Criterion6363Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6363 — Agent calls `get_thread(thread_id: UUID)` with a UUID
  from a prior search response and receives the updated Thread.

  Pre-seeds a Thread row with no comment_tree (simulating a freshly-
  upserted candidate from story 705's search). Calls get_thread with the
  Thread's UUID. Cassette returns Reddit's /comments/<id>.json payload.
  Response carries the updated Thread struct with op_body, comment_tree,
  raw_payload populated.

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

  spex "Agent calls get_thread by UUID and receives the updated Thread" do
    scenario "Pre-seeded Thread refreshed in place from Reddit /comments/<id>.json" do
      given_ "an account with a pre-seeded Thread T (source :reddit, source_thread_id abc123) and a comments cassette",
             context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "abc123",
            url: "https://www.reddit.com/r/elixir/comments/abc123/_/",
            title: "Pre-seeded thread",
            op_body: "",
            comment_tree: %{},
            raw_payload: %{},
            fetched_at: nil
          })

        RedditHelpers.build_comments_cassette!("crit_6363_get",
          source_thread_id: "abc123",
          post: %{
            "title" => "Pre-seeded thread",
            "selftext" => "OP body that arrives via the comments endpoint",
            "score" => 42,
            "num_comments" => 2
          },
          comments: [
            %{body: "First reply", author: "user1", score: 3, id: "cmt1"},
            %{body: "Second reply", author: "user2", score: 1, id: "cmt2"}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent calls get_thread with the Thread's UUID", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6363_get", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "response is the updated Thread with op_body + comment_tree + raw_payload populated",
            context do
        thread = context.payload["thread"] || context.payload

        assert thread["id"] == context.thread.id,
               "expected response Thread.id to equal the input UUID, got: #{inspect(thread["id"])}"

        assert is_binary(thread["op_body"]) and thread["op_body"] != "",
               "expected op_body to be populated, got: #{inspect(thread["op_body"])}"

        assert is_map(thread["comment_tree"]) or is_list(thread["comment_tree"]),
               "expected comment_tree to be populated, got: #{inspect(thread["comment_tree"])}"

        assert thread["raw_payload"] != nil and thread["raw_payload"] != %{},
               "expected raw_payload to be populated, got: #{inspect(thread["raw_payload"])}"

        {:ok, context}
      end
    end
  end
end
