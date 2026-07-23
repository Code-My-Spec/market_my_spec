defmodule MarketMySpecSpex.Story676.Criterion5843Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Account
  Criterion 5843 — Each step file passes the write_file directive audit
  """

  use MarketMySpecSpex.Case

  @skill_root "priv/skills/marketing-strategy"

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

  spex "each step file directs the agent to call write_file with its canonical destination" do
    scenario "all eight step files contain a write_file MCP tool reference and the canonical destination path" do
      given_ "all eight step files", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        step_data =
          Enum.map(@canonical_artifacts, fn {step_file, artifact_path} ->
            content = Path.join(skill_dir, step_file) |> File.read!()
            {step_file, artifact_path, content}
          end)

        {:ok, Map.put(context, :step_data, step_data)}
      end

      then_ "every step file is non-empty (so the audit is not vacuous)", context do
        Enum.each(context.step_data, fn {step_file, _artifact_path, content} ->
          assert byte_size(content) > 0, "Expected #{step_file} to have non-empty content"
        end)

        {:ok, context}
      end

      then_ "each step file references its canonical artifact path", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "Expected canonical destination #{artifact_path} in #{step_file}"
        end)

        {:ok, context}
      end

      then_ "each step file references the write_file MCP tool", context do
        Enum.each(context.step_data, fn {step_file, _artifact_path, content} ->
          assert content =~ "write_file",
                 "Expected write_file MCP tool reference in #{step_file}"
        end)

        {:ok, context}
      end
    end
  end
end
