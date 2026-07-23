defmodule MarketMySpecSpex.Story676.Criterion5845Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Account
  Criterion 5845 — Destination filenames match the canonical 8-entry table
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

  spex "destination filenames the agent passes to write_file match the canonical table" do
    scenario "the union of marketing/ paths in step files exactly matches the canonical 8-entry list" do
      given_ "the canonical 8-entry destination list", context do
        canonical_set =
          @canonical_artifacts
          |> Enum.map(fn {_step, artifact} -> artifact end)
          |> MapSet.new()

        {:ok, Map.put(context, :canonical_set, canonical_set)}
      end

      given_ "the shipped step files and their content", context do
        skill_dir = Application.app_dir(:market_my_spec, @skill_root)

        step_data =
          Enum.map(@canonical_artifacts, fn {step_file, artifact_path} ->
            content = Path.join(skill_dir, step_file) |> File.read!()
            {step_file, artifact_path, content}
          end)

        {:ok, Map.put(context, :step_data, step_data)}
      end

      then_ "each step file references its canonical destination", context do
        Enum.each(context.step_data, fn {step_file, artifact_path, content} ->
          assert content =~ artifact_path,
                 "Expected canonical #{artifact_path} in #{step_file}"
        end)

        {:ok, context}
      end

      then_ "no step file references a marketing/ path outside the canonical set", context do
        Enum.each(context.step_data, fn {step_file, _artifact, content} ->
          extracted =
            Regex.scan(~r/marketing\/[0-9]{2}_[a-z_]+\.md/, content)
            |> List.flatten()
            |> MapSet.new()

          divergent = MapSet.difference(extracted, context.canonical_set)

          assert MapSet.size(divergent) == 0,
                 "#{step_file} references non-canonical marketing/ paths: #{inspect(MapSet.to_list(divergent))}"
        end)

        {:ok, context}
      end

      then_ "every canonical destination path is relative — no leading slash, no accounts/ prefix", context do
        Enum.each(context.step_data, fn {step_file, _artifact, content} ->
          refute content =~ ~r/\/marketing\/[0-9]{2}_[a-z_]+\.md/,
                 "#{step_file} contains an absolute path beginning with /marketing/"

          refute content =~ ~r/accounts\/[^\/\s]+\/marketing\/[0-9]{2}_[a-z_]+\.md/,
                 "#{step_file} exposes the accounts/ prefix — the agent should pass relative paths only"
        end)

        {:ok, context}
      end
    end
  end
end
