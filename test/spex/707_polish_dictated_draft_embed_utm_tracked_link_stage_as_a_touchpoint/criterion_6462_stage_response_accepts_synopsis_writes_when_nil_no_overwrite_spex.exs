defmodule MarketMySpecSpex.Story707.Criterion6462Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as a Touchpoint
  Criterion 6462 — stage_response accepts optional :synopsis; writes to
  thread.synopsis when thread.synopsis is nil; does not overwrite a non-nil
  synopsis on subsequent stages.

  Three stages on the same thread:
    1. Without :synopsis → thread.synopsis stays nil
    2. With :synopsis "First synthesis" → thread.synopsis becomes "First synthesis"
    3. With :synopsis "Second synthesis (should be ignored)" → thread.synopsis still "First synthesis"

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Engagements.ThreadsRepository
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  spex "stage_response writes synopsis on first call, never overwrites" do
    scenario "three stages: no synopsis, then set, then attempted overwrite" do
      given_ "a fresh thread with nil synopsis", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "syn462"})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope), thread: thread})}
      end

      when_ "we stage without synopsis, then with synopsis, then with a different synopsis", context do
        {:reply, _, _} =
          StageResponse.execute(
            %{thread_id: context.thread.id, polished_body: "Body 1", link_target: "https://x"},
            context.frame
          )

        {:ok, after_first} = ThreadsRepository.get_thread_by_id(context.scope, context.thread.id)

        {:reply, _, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Body 2",
              link_target: "https://x",
              synopsis: "First synthesis"
            },
            context.frame
          )

        {:ok, after_second} = ThreadsRepository.get_thread_by_id(context.scope, context.thread.id)

        {:reply, _, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Body 3",
              link_target: "https://x",
              synopsis: "Second synthesis (should be ignored)"
            },
            context.frame
          )

        {:ok, after_third} = ThreadsRepository.get_thread_by_id(context.scope, context.thread.id)

        {:ok,
         Map.merge(context, %{
           after_first: after_first,
           after_second: after_second,
           after_third: after_third
         })}
      end

      then_ "synopsis is nil after stage 1, set after stage 2, unchanged after stage 3", context do
        assert context.after_first.synopsis == nil,
               "expected synopsis nil after stage without :synopsis; got: #{inspect(context.after_first.synopsis)}"

        assert context.after_second.synopsis == "First synthesis",
               "expected synopsis written on first synopsis-bearing stage; got: #{inspect(context.after_second.synopsis)}"

        assert context.after_third.synopsis == "First synthesis",
               "expected synopsis preserved (no overwrite) on subsequent stage; got: #{inspect(context.after_third.synopsis)}"

        {:ok, context}
      end
    end
  end
end
