defmodule MarketMySpecSpex.Story675.Criterion5724Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5724 — Invoking an unknown skill returns a clear MCP error

  The domain layer (`Skills.read_skill_file/1`) must return a clear error
  for files that do not exist. The Step resource propagates this as a
  `resource_not_found` MCP error, so an agent requesting a nonexistent
  skill slug receives a structured error, not an empty or panic response.
  This test calls Step.read/2 with a slug that doesn't correspond to any
  registered step file, verifying the not-found error path.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Resources.Step

  spex "invoking an unknown skill returns a clear MCP error" do
    scenario "Step.read with an unregistered skill slug returns a resource_not_found error" do
      given_ "a server frame with no preconditions", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent requests a step with an unknown slug", context do
        result = Step.read(%{"params" => %{"slug" => "nonexistent-skill-xyz"}}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the MCP response is an error, not file content", context do
        assert match?({:error, _, _}, context.result),
               "expected Step.read with unknown slug to return {:error, _, _}"

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
