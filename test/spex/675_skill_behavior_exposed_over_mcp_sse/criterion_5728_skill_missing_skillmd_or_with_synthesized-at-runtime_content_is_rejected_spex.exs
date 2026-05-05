defmodule MarketMySpecSpex.Story675.Criterion5728Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5728 — Skill missing SKILL.md or with synthesized-at-runtime content is rejected

  Quality gate: SKILL.md must be a real on-disk file with substantive content.
  An implementation that synthesizes the orientation prompt at runtime or omits
  SKILL.md entirely fails this spec.
  """

  use MarketMySpecSpex.Case

  @skill_root "priv/skills/marketing-strategy"

  spex "SKILL.md must be a real on-disk file, not synthesized at runtime" do
    scenario "the SKILL.md file exists and contains canonical skill content" do
      given_ "the marketing-strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the SKILL.md file is non-empty", context do
        assert byte_size(context.skill_md) > 0
        {:ok, context}
      end

      then_ "the SKILL.md contains the canonical skill name", context do
        assert context.skill_md =~ "name: marketing-strategy"
        {:ok, context}
      end

      then_ "the SKILL.md references step files, confirming it is not placeholder content", context do
        # The step files are referenced in the tree listing and in prose.
        # The tree shows them as "01_current_state.md" under the steps/ directory.
        assert context.skill_md =~ "01_current_state.md",
               "expected SKILL.md to list step 1 in its file tree"

        assert context.skill_md =~ "08_plan.md",
               "expected SKILL.md to list step 8 in its file tree"

        {:ok, context}
      end
    end
  end
end
