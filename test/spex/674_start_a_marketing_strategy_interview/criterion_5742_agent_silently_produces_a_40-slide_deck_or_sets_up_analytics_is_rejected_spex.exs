defmodule MarketMySpecSpex.Story674.Criterion5742Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5742 — Agent silently produces a 40-slide deck or sets up analytics is rejected

  Quality gate: the skill must explicitly rule out producing presentation decks
  and setting up tooling/analytics. A playbook without these scope boundaries
  fails this spec.
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "40-slide deck and analytics setup quality gate" do
    scenario "the SKILL.md explicitly prohibits deck production and analytics setup", context do
      given_ "the marketing strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill explicitly rules out producing a slide deck", context do
        assert context.skill_md =~ "What this skill does NOT do"
        assert context.skill_md =~ "40-slide"
        :ok
      end

      then_ "the skill explicitly rules out analytics and tooling setup", context do
        assert context.skill_md =~ "What this skill does NOT do"
        assert context.skill_md =~ "analytics"
        :ok
      end
    end
  end
end
