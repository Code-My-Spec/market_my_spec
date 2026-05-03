defmodule MarketMySpecSpex.Story676.Criterion5794Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Project
  Criterion 5794 — Re-running the interview overwrites stable filenames, not numbered duplicates
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

  spex "re-running the interview overwrites stable filenames, not numbered duplicates" do
    scenario "every step file's write instruction targets a stable filename with no duplicate-suffix variants", context do
      given_ "all eight step files", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        step_data =
          Enum.map(@canonical_artifacts, fn {step_file, artifact_path} ->
            content = Path.join(skill_dir, step_file) |> File.read!()
            {step_file, artifact_path, content}
          end)

        {:ok, Map.put(context, :step_data, step_data)}
      end

      then_ "each step file references its canonical stable artifact path", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "Expected stable path #{artifact_path} in #{step_file}"
        end)

        :ok
      end

      then_ "no step file references a parenthesized-counter duplicate filename", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "anchor: expected stable path #{artifact_path} in #{step_file}"

          refute content =~ ~r/marketing\/[0-9]{2}_[a-z_]+ \([0-9]+\)\.md/,
                 "Expected no duplicate-counter style filename in #{step_file}"

          refute content =~ ~r/marketing\/[0-9]{2}_[a-z_]+_\([0-9]+\)\.md/,
                 "Expected no underscore-counter style filename in #{step_file}"
        end)

        :ok
      end

      then_ "no step file instructs the agent to append a numeric suffix on re-runs", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "anchor: expected stable path #{artifact_path} in #{step_file}"

          refute content =~ ~r/append\s+(?:a\s+)?(?:number|counter|timestamp)/i,
                 "Expected no append-counter instruction in #{step_file}"

          refute content =~ ~r/[Cc]reate (?:a )?new file (?:every|each) (?:run|time|interview)/,
                 "Expected no per-run new-file instruction in #{step_file}"
        end)

        :ok
      end

      then_ "every canonical artifact path uses the stable two-digit numbered scheme", context do
        Enum.each(context.step_data, fn {_step_file, artifact_path, _content} ->
          assert artifact_path =~ ~r/^marketing\/[0-9]{2}_[a-z_]+\.md$/,
                 "Expected stable scheme for #{artifact_path}"

          refute artifact_path =~ ~r/[0-9]{8}/,
                 "Expected no embedded YYYYMMDD in #{artifact_path}"
        end)

        :ok
      end
    end
  end
end
