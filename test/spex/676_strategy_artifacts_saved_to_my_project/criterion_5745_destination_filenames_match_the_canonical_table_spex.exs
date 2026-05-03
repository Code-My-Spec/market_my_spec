defmodule MarketMySpecSpex.Story676.Criterion5745Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Project
  Criterion 5745 — Destination filenames match the canonical table
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

  spex "destination filenames match the canonical table" do
    scenario "each step file's write instruction names the exact canonical artifact filename", context do
      given_ "all eight step files", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        step_data =
          Enum.map(@canonical_artifacts, fn {step_file, artifact_path} ->
            content = Path.join(skill_dir, step_file) |> File.read!()
            {step_file, artifact_path, content}
          end)

        {:ok, Map.put(context, :step_data, step_data)}
      end

      then_ "each step file contains a backtick-quoted write instruction with the canonical filename", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ ~r/[Ww]rite `#{Regex.escape(artifact_path)}`/,
                 "Expected write instruction `#{artifact_path}` in #{step_file}"
        end)

        :ok
      end

      then_ "each canonical filename uses the simple two-digit numbered format", context do
        Enum.each(context.step_data, fn {_step_file, artifact_path, _content} ->
          assert artifact_path =~ ~r/^marketing\/[0-9]{2}_[a-z_]+\.md$/,
                 "Expected canonical format for #{artifact_path}"
        end)

        :ok
      end
    end
  end
end
