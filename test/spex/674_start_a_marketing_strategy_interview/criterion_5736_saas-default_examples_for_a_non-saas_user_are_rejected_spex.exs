defmodule MarketMySpecSpex.Story674.Criterion5736Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5736 — SaaS-default examples for a non-SaaS user are rejected

  Quality gate: the skill must explicitly prohibit defaulting to dev-tool or
  SaaS examples. A playbook without this prohibition fails this spec.
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "SaaS-default examples quality gate" do
    scenario "the SKILL.md explicitly prohibits defaulting to SaaS or dev-tool framing", context do
      given_ "the marketing strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill explicitly prohibits defaulting to dev-tool or SaaS examples", context do
        assert context.skill_md =~ "Do not default to dev-tool, SaaS, or tech examples"
        :ok
      end

      then_ "the prohibition includes a condition for when SaaS examples ARE appropriate", context do
        assert context.skill_md =~ "Do not default to dev-tool, SaaS, or tech examples"
        assert context.skill_md =~ "unless the user's business is"
        :ok
      end
    end
  end
end
