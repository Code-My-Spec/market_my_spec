defmodule MarketMySpecSpex.Story674.Criterion5734Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5734 — Skipping orient and asking interview questions cold is rejected

  Quality gate: the skill playbook must have the Orient step before any interview
  questions. A playbook that jumps straight to interview questions without an
  orient section fails this spec.
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "orient step quality gate" do
    scenario "the SKILL.md contains the orient step gating the interview questions", context do
      given_ "the marketing strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill defines Step 0 Orient before the 8 interview steps", context do
        orient_pos = :binary.match(context.skill_md, "Step 0")
        steps_pos = :binary.match(context.skill_md, "The 8 steps")
        assert orient_pos != :nomatch
        assert steps_pos != :nomatch
        {orient_offset, _} = orient_pos
        {steps_offset, _} = steps_pos
        assert orient_offset < steps_offset
        :ok
      end

      then_ "the orient step instructs the agent to check context before asking anything", context do
        assert context.skill_md =~ "Before touching anything"
        :ok
      end
    end
  end
end
