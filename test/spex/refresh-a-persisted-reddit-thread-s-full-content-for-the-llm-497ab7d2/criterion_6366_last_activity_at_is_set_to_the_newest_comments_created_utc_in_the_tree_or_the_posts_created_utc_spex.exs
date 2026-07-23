defmodule MarketMySpecSpex.Story706.Criterion6366Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6366 — last_activity_at is set to the newest comment's
  created_utc in the tree, or the post's created_utc when there are no
  comments.

  Two scenarios:
  - Thread with comments: last_activity_at equals the MAX(created_utc)
    across all comments (not the post's created_utc).
  - Thread with no comments: last_activity_at falls back to the post's
    created_utc.

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

  # Normalize last_activity_at (ISO8601 string OR Unix epoch number) → integer
  # Unix seconds for assert_in_delta comparisons.
  defp recency_to_unix(value) when is_binary(value) do
    {:ok, dt, _} = DateTime.from_iso8601(value)
    DateTime.to_unix(dt)
  end

  defp recency_to_unix(value) when is_integer(value), do: value
  defp recency_to_unix(value) when is_float(value), do: trunc(value)
  defp recency_to_unix(other), do: flunk("unexpected last_activity_at type: #{inspect(other)}")

  spex "last_activity_at reflects newest comment's created_utc; falls back to post when empty" do
    scenario "Thread with comments: last_activity_at equals max(comment.created_utc)" do
      given_ "a Thread cassette with two comments at distinct created_utc values; post created earlier",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "lact001"})

        RedditHelpers.build_comments_cassette!("crit_6366_with_comments",
          source_thread_id: "lact001",
          post: %{"title" => "With comments", "created_utc" => 1_700_000_000.0},
          comments: [
            %{id: "c_old", body: "earlier", created_utc: 1_700_500_000.0},
            %{id: "c_new", body: "newest", created_utc: 1_711_000_000.0}
          ]
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6366_with_comments", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "last_activity_at corresponds to the newest comment (not the post)", context do
        thread = context.payload["thread"] || context.payload

        # last_activity_at is encoded as iso8601 datetime string OR unix epoch
        # in JSON; compare via Unix-second normalization with ±2s tolerance for
        # serialization/truncation rounding.
        last_activity_at = thread["last_activity_at"]
        assert last_activity_at != nil,
               "expected last_activity_at populated, got nil"

        # Expected: newest comment's created_utc (1_711_000_000.0), NOT the
        # earlier comment (1_700_500_000.0) and NOT the post's created_utc
        # (1_700_000_000.0).
        expected_unix = 1_711_000_000
        actual_unix = recency_to_unix(last_activity_at)

        assert_in_delta actual_unix, expected_unix, 2,
                        "expected last_activity_at to be the NEWEST comment's created_utc (#{expected_unix}), got #{actual_unix}"

        # Sanity: must NOT be the earlier comment or the post
        refute_in_delta actual_unix, 1_700_500_000, 2,
                        "expected newest comment, not earlier one"

        refute_in_delta actual_unix, 1_700_000_000, 2,
                        "expected newest comment, not post.created_utc"

        {:ok, context}
      end
    end

    scenario "Thread with no comments: last_activity_at falls back to post.created_utc" do
      given_ "a Thread cassette with zero comments; post created at a specific time",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "lact002"})

        RedditHelpers.build_comments_cassette!("crit_6366_no_comments",
          source_thread_id: "lact002",
          post: %{"title" => "No comments", "created_utc" => 1_705_555_555.0},
          comments: []
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6366_no_comments", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "last_activity_at equals the post's created_utc", context do
        thread = context.payload["thread"] || context.payload
        last_activity_at = thread["last_activity_at"]

        assert last_activity_at != nil,
               "expected last_activity_at populated (fallback to post.created_utc)"

        expected_unix = 1_705_555_555
        actual_unix = recency_to_unix(last_activity_at)

        assert_in_delta actual_unix, expected_unix, 2,
                        "expected last_activity_at to fall back to post.created_utc (#{expected_unix}), got #{actual_unix}"

        {:ok, context}
      end
    end
  end
end
