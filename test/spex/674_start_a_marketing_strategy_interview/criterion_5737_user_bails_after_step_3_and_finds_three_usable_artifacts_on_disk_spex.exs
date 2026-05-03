defmodule MarketMySpecSpex.Story674.Criterion5737Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5737 — User bails after step 3 and finds three usable artifacts on disk
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "incremental artifact writes are required after each step" do
    scenario "the SKILL.md instructs the agent to write artifacts as each step completes", context do
      given_ "the marketing strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill instructs writing artifacts incrementally, not batched", context do
        assert context.skill_md =~ "Don't batch"
        assert context.skill_md =~ "if the user bails after step 3"
        :ok
      end

      then_ "the skill specifies one artifact per step", context do
        assert context.skill_md =~ "marketing/01_current_state.md"
        assert context.skill_md =~ "marketing/02_jobs_and_segments.md"
        assert context.skill_md =~ "marketing/03_personas.md"
        :ok
      end

      then_ "the skill instructs writing the artifact before moving to the next step", context do
        assert context.skill_md =~ "Write artifacts as you go"
        :ok
      end
    end
  end
end
