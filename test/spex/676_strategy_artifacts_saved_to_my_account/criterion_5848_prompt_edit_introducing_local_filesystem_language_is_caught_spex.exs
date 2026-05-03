defmodule MarketMySpecSpex.Story676.Criterion5848Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Account
  Criterion 5848 — Prompt edit introducing local-filesystem language is caught by the sweep
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

  spex "any prompt edit that drifts toward local-filesystem framing is caught (regression)" do
    scenario "every shipped skill file currently passes the banned-phrase sweep" do
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

      then_ "every file is non-empty (so the regression catch is not vacuous)", context do
        Enum.each(context.file_data, fn {rel, content} ->
          assert byte_size(content) > 0, "Expected #{rel} to have non-empty content"
        end)

        {:ok, context}
      end

      then_ "no current skill file contains a local-filesystem phrase, line by line", context do
        Enum.each(context.file_data, fn {rel, content_lc} ->
          lines = String.split(content_lc, "\n")

          Enum.with_index(lines, 1)
          |> Enum.each(fn {line, line_no} ->
            Enum.each(@banned_phrases, fn phrase ->
              refute String.contains?(line, phrase),
                     "Regression: #{rel}:#{line_no} contains banned local-filesystem phrase \"#{phrase}\". Rephrase to delegate the write to the write_file MCP tool with a relative canonical path."
            end)
          end)
        end)

        {:ok, context}
      end

      then_ "no step file says 'use your Write tool' (the canonical pre-pivot phrase)", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        @step_files
        |> Enum.each(fn step ->
          content = Path.join(skill_dir, step) |> File.read!()

          refute content =~ ~r/use your Write tool/i,
                 "Regression: #{step} contains 'use your Write tool' — replace with 'call the write_file MCP tool'"
        end)

        {:ok, context}
      end
    end
  end
end
