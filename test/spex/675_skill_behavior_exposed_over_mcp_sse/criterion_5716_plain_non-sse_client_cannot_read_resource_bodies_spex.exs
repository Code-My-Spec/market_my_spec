defmodule MarketMySpecSpex.Story675.Criterion5716Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5716 — Plain non-SSE client cannot read resource bodies

  The MCP resource protocol requires an established SSE session before
  resources/read is meaningful. At the domain layer, Step.read/2 enforces
  a slug parameter and returns a protocol error for malformed or missing
  params, confirming the resource is not freely accessible without proper
  MCP session negotiation. SSE transport negotiation is handled by Anubis.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Resources.Step

  spex "plain HTTP client is rejected when attempting to read resource bodies" do
    scenario "Step.read without required slug parameter returns a protocol error" do
      given_ "a server frame with no active session", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the resource is called without a slug parameter", context do
        result = Step.read(%{}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the resource returns an error, not file content", context do
        assert match?({:error, _, _}, context.result),
               "expected Step.read without slug to return {:error, _, _}"

        {:ok, context}
      end

      then_ "the error is a protocol-level invalid_params error", context do
        {:error, %Anubis.MCP.Error{reason: reason}, _frame} = context.result

        assert reason == :invalid_params,
               "expected :invalid_params reason, got: #{inspect(reason)}"

        {:ok, context}
      end
    end
  end
end
