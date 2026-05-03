defmodule MarketMySpecSpex.Story674.Criterion5738Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5738 — Batched end-of-run artifact writes are rejected

  Quality gate: the skill must explicitly prohibit batching artifact writes
  to the end of the run. A playbook without this prohibition fails this spec.
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "batched artifact writes quality gate" do
    scenario "the SKILL.md explicitly forbids batching artifact writes" do
      given_ "the marketing strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill explicitly says do not batch writes", context do
        assert context.skill_md =~ "Don't batch"
        {:ok, context}
      end

      then_ "the no-batch rule includes the rationale about bailing users", context do
        assert context.skill_md =~ "Don't batch"
        assert context.skill_md =~ "three usable files"
        {:ok, context}
      end
    end
  end
end
