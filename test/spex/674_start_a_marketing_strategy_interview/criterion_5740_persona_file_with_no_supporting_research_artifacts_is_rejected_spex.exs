defmodule MarketMySpecSpex.Story674.Criterion5740Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5740 — Persona file with no supporting research artifacts is rejected

  Quality gate: step 3 must produce research artifact files before synthesizing
  the persona document. A playbook that produces only the persona file without
  research backing fails this spec.
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  spex "persona file requires supporting research artifacts quality gate" do
    scenario "step 3 specifies research artifacts as a prerequisite to the persona file", context do
      given_ "the step 3 persona research file", context do
        step_md =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("steps/03_persona_research.md")
          |> File.read!()

        {:ok, Map.put(context, :step_md, step_md)}
      end

      then_ "step 3 lists research artifacts as separate required outputs", context do
        assert context.step_md =~ "marketing/research/"
        assert context.step_md =~ "marketing/03_personas.md"
        :ok
      end

      then_ "the research artifacts are specified before the synthesized persona file", context do
        research_pos = :binary.match(context.step_md, "marketing/research/")
        persona_pos = :binary.match(context.step_md, "marketing/03_personas.md")
        assert research_pos != :nomatch
        assert persona_pos != :nomatch
        {research_offset, _} = research_pos
        {persona_offset, _} = persona_pos
        assert research_offset < persona_offset
        :ok
      end

      then_ "step 3 explicitly requires synthesizing from research, not inventing personas", context do
        assert context.step_md =~ "synthesize"
        assert context.step_md =~ "research"
        :ok
      end
    end
  end
end
