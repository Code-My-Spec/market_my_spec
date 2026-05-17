defmodule MarketMySpecSpex.Story706.Criterion6374Spex do
  @moduledoc """
  Story 706 — Refresh a persisted Reddit Thread's full content for the LLM
  Criterion 6374 — get_thread is idempotent within the freshness window
  — repeat calls produce identical Thread state with no side effects.

  Pre-seed a Thread within the 5-min freshness window. Two back-to-back
  get_thread calls — both return identical Thread payloads. Cassette
  has zero interactions, so no HTTP, no row mutation, no side effects.

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

  spex "Within freshness window, get_thread is idempotent (repeat = identical)" do
    scenario "Two back-to-back get_thread calls produce identical payloads" do
      given_ "a Thread fetched 30s ago with populated content; cassette is empty",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        recent = DateTime.utc_now() |> DateTime.add(-30) |> DateTime.truncate(:second)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "idem001",
            fetched_at: recent,
            op_body: "Idempotent op body",
            comment_tree: %{"children" => []}
          })

        cassette_path = "test/cassettes/reddit/crit_6374_idempotent.json"
        File.mkdir_p!("test/cassettes/reddit")
        File.write!(cassette_path, Jason.encode!(%{"version" => "1.0", "interactions" => []}))
        ExUnit.Callbacks.on_exit(fn -> File.rm(cassette_path) end)

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent calls get_thread twice in succession", context do
        run = fn ->
          {:reply, response, _frame} =
            RedditHelpers.with_reddit_cassette("crit_6374_idempotent", fn ->
              GetThread.execute(%{thread_id: context.thread.id}, context.frame)
            end)

          decode_payload(response)
        end

        first = run.()
        second = run.()
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "both calls return identical Thread payloads (idempotent)", context do
        first_thread = context.first["thread"] || context.first
        second_thread = context.second["thread"] || context.second

        assert first_thread["id"] == context.thread.id,
               "expected UUID preserved across calls"

        assert first_thread == second_thread,
               "expected identical Thread payloads across calls (idempotent)"

        {:ok, context}
      end
    end
  end
end
