defmodule MarketMySpecSpex.Story674.Criterion5739Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5739 — Step 3 dispatches research subagents and grounds personas in evidence

  The step 3 file must be accessible via the MCP resource system and must
  instruct the agent to dispatch research agents and run them in parallel.

  Two surfaces tested:
  1. `StartInterview.execute/2` — the orientation lists step 3's resource URI.
  2. `Skills.read_skill_file/1` — the step 3 file content has the required instructions.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview
  alias MarketMySpec.Skills

  spex "step 3 dispatches research agents and grounds personas in evidence" do
    scenario "start_interview lists step 3 URI and the step file instructs research agent dispatch" do
      given_ "no preconditions", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview and then fetches step 3", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, step_md} = Skills.read_skill_file("steps/03_persona_research.md")

        context =
          context
          |> Map.put(:orientation, response_text(response))
          |> Map.put(:step_md, step_md)

        {:ok, context}
      end

      then_ "the orientation includes the step 3 resource URI", context do
        assert context.orientation =~ "marketing-strategy://steps/03_persona_research",
               "expected step 3 resource URI in the orientation"

        {:ok, context}
      end

      then_ "step 3 instructs dispatching research agents per segment", context do
        assert context.step_md =~ "research agent",
               "expected 'research agent' instruction in step 3"

        assert context.step_md =~ "Dispatch",
               "expected 'Dispatch' instruction in step 3"

        {:ok, context}
      end

      then_ "step 3 instructs running agents in parallel", context do
        assert context.step_md =~ "parallel",
               "expected 'parallel' in step 3"

        assert context.step_md =~ "in parallel",
               "expected 'in parallel' instruction in step 3"

        {:ok, context}
      end

      then_ "step 3 names the research artifacts that must be produced", context do
        assert context.step_md =~ "marketing/research/persona_",
               "expected research artifact path in step 3"

        assert context.step_md =~ "marketing/03_personas.md",
               "expected persona synthesis artifact path in step 3"

        {:ok, context}
      end
    end
  end

  defp response_text(%{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{text: t} -> t
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(%{text: text}), do: text
  defp response_text(other), do: inspect(other)
end
