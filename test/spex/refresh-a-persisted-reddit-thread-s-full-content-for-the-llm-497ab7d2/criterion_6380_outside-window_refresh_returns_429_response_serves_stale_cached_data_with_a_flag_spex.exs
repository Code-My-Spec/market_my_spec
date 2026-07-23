defmodule MarketMySpecSpex.Story706.Criterion6380Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6380 — Outside-window refresh returns 429; response serves
  stale cached data with a flag.

  Sister to 6371; pinned via Three Amigos scenario. Thread fetched 10
  min ago (outside 5-min window). Cassette returns 429. Response carries
  the stale cached data PLUS a stale_warning {reason, age_seconds}.

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

  spex "Outside-window 429: stale cached data with stale_warning flag" do
    scenario "Thread fetched 10min ago; cassette returns 429; envelope has stale data + warning" do
      given_ "a Thread fetched 10min ago with populated content; cassette returns 429",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        stale = DateTime.utc_now() |> DateTime.add(-600) |> DateTime.truncate(:second)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "stale429_001",
            fetched_at: stale,
            op_body: "Stale cached op body",
            comment_tree: %{
              "children" => [
                %{"author" => "u1", "body" => "Stale comment", "score" => 5,
                  "created_utc" => 1_700_000_000.0, "depth" => 0}
              ]
            }
          })

        RedditHelpers.build_comments_cassette!("crit_6380_stale429",
          source_thread_id: "stale429_001",
          status: 429
        )

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls get_thread; cassette returns 429", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6380_stale429", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "response carries stale cached data + a stale_warning map", context do
        thread = context.payload["thread"] || context.payload

        assert thread["op_body"] == "Stale cached op body",
               "expected cached op_body preserved, got: #{inspect(thread["op_body"])}"

        warning = context.payload["stale_warning"] || thread["stale_warning"]
        assert is_map(warning),
               "expected stale_warning map in response, got: #{inspect(warning)}"

        # stale_warning should carry reason and age_seconds
        reason = warning["reason"] || warning[:reason]
        age = warning["age_seconds"] || warning[:age_seconds]

        assert reason in ["rate_limited", :rate_limited, "429"],
               "expected reason=:rate_limited or similar, got: #{inspect(reason)}"

        assert is_integer(age) and age >= 500,
               "expected age_seconds ~600, got: #{inspect(age)}"

        {:ok, context}
      end
    end
  end
end
