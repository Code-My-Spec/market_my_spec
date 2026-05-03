defmodule MarketMySpecSpex.Story674.Criterion5733Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5733 — Agent skims project context before asking the first question
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "agent skims project context before asking the first question" do
    scenario "the SKILL.md instructs the agent to read existing project context before any interview question" do
      given_ "the marketing strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill includes a Step 0 Orient section", context do
        assert context.skill_md =~ "Step 0"
        assert context.skill_md =~ "Orient"
        {:ok, context}
      end

      then_ "the orient step instructs the agent to check for existing marketing artifacts", context do
        assert context.skill_md =~ "Check whether `marketing/` already exists"
        {:ok, context}
      end

      then_ "the orient step instructs the agent to skim project context files", context do
        assert context.skill_md =~ "README.md"
        assert context.skill_md =~ "mix.exs"
        {:ok, context}
      end

      then_ "the orient step instructs reading before asking questions", context do
        assert context.skill_md =~ "before asking"
        assert context.skill_md =~ "Don't make the user type things you can read"
        {:ok, context}
      end
    end
  end
end
