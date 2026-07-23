defmodule MarketMySpecSpex.Story676.Criterion5846Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Account
  Criterion 5846 — Drifted filename (timestamped, versioned, or absolute) is rejected
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

  spex "drifted filename variants are rejected by the audit" do
    scenario "no step file references timestamped, versioned, or absolute filename variants" do
      given_ "all eight step files", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        step_data =
          Enum.map(@canonical_artifacts, fn {step_file, artifact_path} ->
            content = Path.join(skill_dir, step_file) |> File.read!()
            {step_file, artifact_path, content}
          end)

        {:ok, Map.put(context, :step_data, step_data)}
      end

      then_ "each step file references its canonical artifact path", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "Expected canonical #{artifact_path} in #{step_file}"
        end)

        {:ok, context}
      end

      then_ "no step file contains a timestamped filename variant", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "anchor: expected canonical #{artifact_path} in #{step_file}"

          refute content =~ ~r/marketing\/[0-9]{2}_[a-z_]+_\d{8}\.md/,
                 "Expected no YYYYMMDD-suffixed filename in #{step_file}"

          refute content =~ ~r/marketing\/[0-9]{2}_[a-z_]+_\d{4}-\d{2}-\d{2}\.md/,
                 "Expected no ISO-date-suffixed filename in #{step_file}"
        end)

        {:ok, context}
      end

      then_ "no step file contains a versioned filename variant", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "anchor: expected canonical #{artifact_path} in #{step_file}"

          refute content =~ ~r/marketing\/[0-9]{2}_[a-z_]+_v[0-9]+\.md/,
                 "Expected no _vN-suffixed filename in #{step_file}"

          refute content =~ ~r/marketing\/[0-9]{2}_[a-z_]+_(?:copy|final|new|old)\.md/,
                 "Expected no copy/final/new/old-suffixed filename in #{step_file}"
        end)

        {:ok, context}
      end

      then_ "no step file contains an absolute /marketing path or an accounts/ prefix", context do
        Enum.each(context.step_data, fn {step_file, _artifact_path, content} ->
          refute content =~ ~r/\/marketing\/[0-9]{2}_[a-z_]+\.md/,
                 "Found absolute /marketing/ path in #{step_file} — agent must pass relative paths only"

          refute content =~ ~r/accounts\/[^\/\s]+\/marketing\//,
                 "Found accounts/ prefix in #{step_file} — server adds the prefix; the agent should not"
        end)

        {:ok, context}
      end
    end
  end
end
