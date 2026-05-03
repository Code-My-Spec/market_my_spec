defmodule MarketMySpecSpex.Story676.Criterion5749Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Project
  Criterion 5749 — Skill content sweep finds no hosted-doc language
  """

  use MarketMySpecSpex.Case

  @skill_root "skills/marketing-strategy"

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

  @hosted_doc_phrases [
    "we'll save",
    "we will save",
    "we'll store",
    "we will store",
    "stored for you",
    "saved to your dashboard",
    "your dashboard",
    "download your strategy",
    "download your plan",
    "hosted at",
    "hosted on our",
    "stored on our servers",
    "uploaded to your account",
    "saved on the server"
  ]

  spex "skill content sweep finds no hosted-doc language" do
    scenario "all skill files use local-write language, not hosted/dashboard language", context do
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

        :ok
      end

      then_ "no skill file contains any hosted-doc phrase", context do
        Enum.each(context.file_data, fn {rel, content_lc} ->
          assert byte_size(content_lc) > 0,
                 "anchor: expected #{rel} to be non-empty for the sweep to be meaningful"

          Enum.each(@hosted_doc_phrases, fn phrase ->
            refute String.contains?(content_lc, phrase),
                   "Found hosted-doc phrase \"#{phrase}\" in #{rel}"
          end)
        end)

        :ok
      end

      then_ "every step file uses local-write language pointing to marketing/", context do
        Enum.each(context.file_data, fn {rel, content_lc} ->
          if rel != "SKILL.md" do
            assert content_lc =~ "marketing/",
                   "Expected local marketing/ path reference in #{rel}"
          end
        end)

        :ok
      end
    end
  end
end
