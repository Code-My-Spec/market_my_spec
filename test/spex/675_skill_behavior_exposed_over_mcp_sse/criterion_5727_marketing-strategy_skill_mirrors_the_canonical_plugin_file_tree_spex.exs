defmodule MarketMySpecSpex.Story675.Criterion5727Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5727 — Marketing-strategy skill mirrors the canonical plugin file tree
  """

  use MarketMySpecSpex.Case

  @skill_root "priv/skills/marketing-strategy"

  spex "marketing-strategy skill mirrors the canonical plugin file tree" do
    scenario "the priv/skills/marketing-strategy directory contains all required files" do
      given_ "the marketing-strategy skill root directory", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)
        {:ok, Map.put(context, :skill_dir, skill_dir)}
      end

      then_ "the SKILL.md orientation file is present", context do
        assert File.exists?(Path.join(context.skill_dir, "SKILL.md"))
        {:ok, context}
      end

      then_ "all eight step files are present under steps/", context do
        assert File.exists?(Path.join(context.skill_dir, "steps/01_current_state.md"))
        assert File.exists?(Path.join(context.skill_dir, "steps/02_jobs_and_segments.md"))
        assert File.exists?(Path.join(context.skill_dir, "steps/03_persona_research.md"))
        assert File.exists?(Path.join(context.skill_dir, "steps/04_beachhead.md"))
        assert File.exists?(Path.join(context.skill_dir, "steps/05_positioning.md"))
        assert File.exists?(Path.join(context.skill_dir, "steps/06_messaging.md"))
        assert File.exists?(Path.join(context.skill_dir, "steps/07_channels.md"))
        assert File.exists?(Path.join(context.skill_dir, "steps/08_plan.md"))
        {:ok, context}
      end
    end
  end
end
