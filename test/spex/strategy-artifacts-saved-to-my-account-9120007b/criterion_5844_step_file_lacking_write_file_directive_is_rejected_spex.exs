defmodule MarketMySpecSpex.Story676.Criterion5844Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Account
  Criterion 5844 — Step file lacking write_file directive is rejected by the audit
  """

  use MarketMySpecSpex.Case

  @skill_root "priv/skills/marketing-strategy"

  @step_files [
    {"steps/01_current_state.md", "marketing/01_current_state.md"},
    {"steps/02_jobs_and_segments.md", "marketing/02_jobs_and_segments.md"},
    {"steps/03_persona_research.md", "marketing/03_personas.md"},
    {"steps/04_beachhead.md", "marketing/04_beachhead.md"},
    {"steps/05_positioning.md", "marketing/05_positioning.md"},
    {"steps/06_messaging.md", "marketing/06_messaging.md"},
    {"steps/07_channels.md", "marketing/07_channels.md"},
    {"steps/08_plan.md", "marketing/08_plan.md"}
  ]

  spex "the static audit rejects any step file that lost its write_file directive" do
    scenario "every shipped step file currently passes both halves of the directive audit (regression catch)" do
      given_ "the shipped step files", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        step_data =
          Enum.map(@step_files, fn {step_file, artifact_path} ->
            content = Path.join(skill_dir, step_file) |> File.read!()
            {step_file, artifact_path, content}
          end)

        {:ok, Map.put(context, :step_data, step_data)}
      end

      then_ "every step file currently contains its canonical destination path", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "Regression: #{step_file} lost its canonical destination path #{artifact_path}. Restore the directive."
        end)

        {:ok, context}
      end

      then_ "every step file currently references the write_file MCP tool", context do
        Enum.each(context.step_data, fn {step_file, _artifact_path, content} ->
          assert content =~ "write_file",
                 "Regression: #{step_file} lost its write_file MCP tool reference. Restore the directive."
        end)

        {:ok, context}
      end

      then_ "no step file uses the agent's local Write tool to persist artifacts", context do
        Enum.each(context.step_data, fn {step_file, _artifact_path, content} ->
          refute content =~ ~r/\bWrite\s+tool\b/,
                 "Regression: #{step_file} references a local 'Write tool' (with a capital W) — artifacts must persist via the write_file MCP tool, not the agent's local filesystem"
        end)

        {:ok, context}
      end
    end
  end
end
