defmodule MarketMySpecSpex.Story674.Criterion5731Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5731 — User runs /marketing-strategy and the agent loads the playbook
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "user runs /marketing-strategy and the agent loads the playbook" do
    scenario "the marketing-strategy SKILL.md is present and structured as an actionable playbook" do
      given_ "the marketing strategy skill file", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill is named marketing-strategy", context do
        assert context.skill_md =~ "name: marketing-strategy"
        {:ok, context}
      end

      then_ "the playbook references the eight step files", context do
        assert context.skill_md =~ "steps/01_current_state.md"
        assert context.skill_md =~ "steps/08_plan.md"
        {:ok, context}
      end

      then_ "the playbook describes an 8-step guided flow", context do
        assert context.skill_md =~ "8-step"
        assert context.skill_md =~ "Step 0"
        {:ok, context}
      end
    end
  end
end
