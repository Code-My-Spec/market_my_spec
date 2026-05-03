defmodule MarketMySpecSpex.Story674.Criterion5735Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5735 — Restaurant owner gets restaurant examples and one-question cadence
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "skill adapts examples to the user's business type and uses one-question cadence" do
    scenario "the SKILL.md is industry-agnostic and enforces a single-question interview pace", context do
      given_ "the marketing strategy SKILL.md", context do
        skill_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("SKILL.md")
          |> File.read!()

        {:ok, Map.put(context, :skill_md, skill_md)}
      end

      then_ "the skill explicitly covers non-software business types", context do
        assert context.skill_md =~ "restaurant"
        assert context.skill_md =~ "local business"
        :ok
      end

      then_ "the skill instructs one or two questions at a time", context do
        assert context.skill_md =~ "one or two questions at a time"
        :ok
      end

      then_ "the skill instructs adapting examples to the user's business type", context do
        assert context.skill_md =~ "Adapt to the business type"
        :ok
      end
    end
  end
end
