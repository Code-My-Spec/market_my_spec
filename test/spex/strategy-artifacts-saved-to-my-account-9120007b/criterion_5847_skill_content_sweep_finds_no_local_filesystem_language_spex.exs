defmodule MarketMySpecSpex.Story676.Criterion5847Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Account
  Criterion 5847 — Skill content sweep finds no local-filesystem language
  """

  use MarketMySpecSpex.Case

  @skill_root "priv/skills/marketing-strategy"

  @step_files [
    "steps/01_current_state.md",
    "steps/02_jobs_and_segments.md",
    "steps/03_persona_research.md",
    "steps/04_beachhead.md",
    "steps/05_positioning.md",
    "steps/06_messaging.md",
    "steps/07_channels.md",
    "steps/08_plan.md"
  ]

  @banned_phrases [
    "write tool",
    "./marketing/",
    "your local marketing",
    "in your working directory",
    "commit to git locally",
    "on the user's machine",
    "local filesystem"
  ]

  spex "skill content sweep finds no local-filesystem language" do
    scenario "all skill files use hosted-via-MCP language, not local-filesystem language" do
      given_ "all skill files (SKILL.md and the eight steps)", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        all_files = ["SKILL.md" | @step_files]

        file_data =
          Enum.map(all_files, fn rel ->
            content = Path.join(skill_dir, rel) |> File.read!()
            {rel, String.downcase(content)}
          end)

        {:ok, Map.put(context, :file_data, file_data)}
      end

      then_ "every file is non-empty (so refutes are not vacuous)", context do
        Enum.each(context.file_data, fn {rel, content} ->
          assert byte_size(content) > 0, "Expected #{rel} to have non-empty content"
        end)

        {:ok, context}
      end

      then_ "no skill file contains any local-filesystem phrase", context do
        Enum.each(context.file_data, fn {rel, content_lc} ->
          assert byte_size(content_lc) > 0,
                 "anchor: expected #{rel} to be non-empty for the sweep to be meaningful"

          Enum.each(@banned_phrases, fn phrase ->
            refute String.contains?(content_lc, phrase),
                   "Found local-filesystem phrase \"#{phrase}\" in #{rel}"
          end)
        end)

        {:ok, context}
      end

      then_ "every step file references the write_file MCP tool and the canonical marketing/ path", context do
        Enum.each(context.file_data, fn {rel, content_lc} ->
          if rel != "SKILL.md" do
            assert content_lc =~ "write_file",
                   "Expected write_file MCP tool reference in #{rel}"

            assert content_lc =~ "marketing/",
                   "Expected canonical marketing/ path reference in #{rel}"
          end
        end)

        {:ok, context}
      end
    end
  end
end
