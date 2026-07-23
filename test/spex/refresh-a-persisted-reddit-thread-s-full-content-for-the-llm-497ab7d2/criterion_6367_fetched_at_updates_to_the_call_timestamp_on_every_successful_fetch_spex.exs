defmodule MarketMySpecSpex.Story706.Criterion6367Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6367 — fetched_at updates to the call timestamp on every
  successful fetch.

  Pre-seed a Thread with an old fetched_at (10 minutes ago). Call
  get_thread (cassette returns 200). After the call, the response's
  fetched_at is at or after a captured "before" timestamp — proving the
  field was updated to the call time, not preserved as old.

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

  defp parse_dt(value) do
    cond do
      is_binary(value) ->
        {:ok, dt, _} = DateTime.from_iso8601(value)
        dt

      is_number(value) ->
        DateTime.from_unix!(trunc(value))

      true ->
        nil
    end
  end

  spex "fetched_at updates to the call timestamp on every successful fetch" do
    scenario "Pre-seeded Thread with old fetched_at; refresh updates fetched_at" do
      given_ "a Thread with fetched_at 10 minutes ago", context do
        scope = Fixtures.account_scoped_user_fixture()
        old_fetched_at = DateTime.utc_now() |> DateTime.add(-600) |> DateTime.truncate(:second)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "fetch001",
            fetched_at: old_fetched_at
          })

        RedditHelpers.build_comments_cassette!("crit_6367_fetched",
          source_thread_id: "fetch001",
          post: %{"title" => "Fetched-at probe"},
          comments: []
        )

        before_call = DateTime.utc_now() |> DateTime.truncate(:second)

        {:ok,
         Map.merge(context, %{
           frame: build_frame(scope),
           thread: thread,
           old_fetched_at: old_fetched_at,
           before_call: before_call
         })}
      end

      when_ "the agent calls get_thread", context do
        {:reply, response, _frame} =
          RedditHelpers.with_reddit_cassette("crit_6367_fetched", fn ->
            GetThread.execute(%{thread_id: context.thread.id}, context.frame)
          end)

        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "the response Thread's fetched_at is at or after the before_call timestamp",
            context do
        thread = context.payload["thread"] || context.payload
        new_fetched_at = parse_dt(thread["fetched_at"])

        assert new_fetched_at != nil, "expected fetched_at populated"

        assert DateTime.compare(new_fetched_at, context.before_call) in [:gt, :eq],
               "expected fetched_at >= before_call (proving the refresh updated it); got: fetched_at=#{new_fetched_at}, before_call=#{context.before_call}"

        assert DateTime.compare(new_fetched_at, context.old_fetched_at) == :gt,
               "expected new fetched_at > old fetched_at; got new=#{new_fetched_at}, old=#{context.old_fetched_at}"

        {:ok, context}
      end
    end
  end
end
