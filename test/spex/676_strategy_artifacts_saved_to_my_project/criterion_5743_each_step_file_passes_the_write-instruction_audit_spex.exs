defmodule MarketMySpecSpex.Story676.Criterion5743Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Project
  Criterion 5743 — Each step file passes the write-instruction audit
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

  @canonical_artifacts [
    {"steps/01_current_state.md", "marketing/01_current_state.md"},
    {"steps/02_jobs_and_segments.md", "marketing/02_jobs_and_segments.md"},
    {"steps/03_persona_research.md", "marketing/03_personas.md"},
    {"steps/04_beachhead.md", "marketing/04_beachhead.md"},
    {"steps/05_positioning.md", "marketing/05_positioning.md"},
    {"steps/06_messaging.md", "marketing/06_messaging.md"},
    {"steps/07_channels.md", "marketing/07_channels.md"},
    {"steps/08_plan.md", "marketing/08_plan.md"}
  ]

  spex "each step file passes the write-instruction audit" do
    scenario "all eight step files contain a write instruction pointing to the local marketing/ directory", context do
      given_ "all eight step files", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        step_data =
          Enum.map(@canonical_artifacts, fn {step_file, artifact_path} ->
            content = Path.join(skill_dir, step_file) |> File.read!()
            {step_file, artifact_path, content}
          end)

        {:ok, Map.put(context, :step_data, step_data)}
      end

      then_ "each step file references its canonical artifact path under marketing/", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "Expected #{artifact_path} write instruction in #{step_file}"
        end)

        :ok
      end

      then_ "each artifact path is under the local marketing/ directory, not a server URL", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path
          assert String.starts_with?(artifact_path, "marketing/"),
                 "Expected artifact path to be local in #{step_file}"
        end)

        :ok
      end
    end
  end
end
