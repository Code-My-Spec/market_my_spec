defmodule MarketMySpecSpex.Story674.Criterion5741Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5741 — User asks for a blog post and the agent deflects to downstream content
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "skill deflects blog post requests to downstream content work" do
    scenario "the SKILL.md explicitly excludes blog post and content production from scope", context do
      given_ "the marketing strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill defines a scope boundary excluding blog post creation", context do
        assert context.skill_md =~ "What this skill does NOT do"
        assert context.skill_md =~ "blog posts"
        :ok
      end

      then_ "the exclusion frames blog posts as downstream content work", context do
        assert context.skill_md =~ "downstream content"
        :ok
      end
    end
  end
end
