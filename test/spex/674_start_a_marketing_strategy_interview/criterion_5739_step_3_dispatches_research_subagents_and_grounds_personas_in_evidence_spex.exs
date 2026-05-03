defmodule MarketMySpecSpex.Story674.Criterion5739Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5739 — Step 3 dispatches research subagents and grounds personas in evidence
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "step 3 dispatches research agents and grounds personas in evidence" do
    scenario "the step 3 persona research file instructs the agent to dispatch research subagents" do
      given_ "the step 3 persona research file", context do
        step_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("steps/03_persona_research.md")
          |> File.read!()

        {:ok, Map.put(context, :step_md, step_md)}
      end

      then_ "step 3 instructs dispatching research agents per segment", context do
        assert context.step_md =~ "research agent"
        assert context.step_md =~ "Dispatch"
        {:ok, context}
      end

      then_ "step 3 instructs running agents in parallel", context do
        assert context.step_md =~ "parallel"
        assert context.step_md =~ "in parallel"
        {:ok, context}
      end

      then_ "step 3 names the research artifacts that must be produced", context do
        assert context.step_md =~ "marketing/research/persona_"
        assert context.step_md =~ "marketing/03_personas.md"
        {:ok, context}
      end
    end
  end
end
