defmodule MarketMySpecSpex.Story675.Criterion5726Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5726 — Reading a non-existent step file returns a not-found error

  When an agent requests a step slug that has no corresponding file on disk,
  the Step resource must return a `resource_not_found` MCP error — not an
  empty body, not a crash. This test calls Step.read/2 directly with a
  slug that has no backing file.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Resources.Step

  spex "reading a non-existent step file returns a not-found error" do
    scenario "Step.read for a missing slug returns resource_not_found" do
      given_ "a server frame with no preconditions", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent requests a step file that does not exist", context do
        result =
          Step.read(
            %{"params" => %{"slug" => "99_nonexistent_step"}},
            context.frame
          )

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response is a not-found error, not file content", context do
        assert match?({:error, _, _}, context.result),
               "expected {:error, _, _} for missing step, got: #{inspect(context.result)}"

        {:ok, context}
      end

      then_ "the error reason is resource_not_found", context do
        {:error, %Anubis.MCP.Error{reason: reason}, _frame} = context.result

        assert reason == :resource_not_found,
               "expected :resource_not_found reason, got: #{inspect(reason)}"

        {:ok, context}
      end
    end
  end
end
