defmodule MarketMySpecSpex.Story674.Criterion5740Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5740 — Persona file with no supporting research artifacts is rejected

  Quality gate: step 3 must specify research artifact files as a prerequisite
  to the synthesized persona document, and the research artifacts must appear
  before the persona file in the step instructions.

  Surface: `Skills.read_skill_file/1` — the step 3 file content has the ordering
  and synthesis requirements. The `StartInterview` tool is also called to confirm
  step 3's resource URI is advertised.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview
  alias MarketMySpec.Skills

  spex "persona file requires supporting research artifacts quality gate" do
    scenario "step 3 specifies research artifacts as a prerequisite to the persona file" do
      given_ "no preconditions", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview and then reads the step 3 file", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, step_md} = Skills.read_skill_file("steps/03_persona_research.md")

        context =
          context
          |> Map.put(:orientation, response_text(response))
          |> Map.put(:step_md, step_md)

        {:ok, context}
      end

      then_ "the orientation advertises the step 3 resource URI", context do
        assert context.orientation =~ "marketing-strategy://steps/03_persona_research",
               "expected step 3 resource URI in the orientation"

        {:ok, context}
      end

      then_ "step 3 lists research artifacts as separate required outputs", context do
        assert context.step_md =~ "marketing/research/",
               "expected research artifact path in step 3"

        assert context.step_md =~ "marketing/03_personas.md",
               "expected persona synthesis artifact path in step 3"

        {:ok, context}
      end

      then_ "the research artifacts are specified before the synthesized persona file", context do
        research_pos = :binary.match(context.step_md, "marketing/research/")
        persona_pos = :binary.match(context.step_md, "marketing/03_personas.md")

        assert research_pos != :nomatch,
               "expected 'marketing/research/' to appear in step 3"

        assert persona_pos != :nomatch,
               "expected 'marketing/03_personas.md' to appear in step 3"

        {research_offset, _} = research_pos
        {persona_offset, _} = persona_pos

        assert research_offset < persona_offset,
               "expected research artifacts to appear before the persona file in step 3"

        {:ok, context}
      end

      then_ "step 3 requires synthesizing from research, not inventing personas", context do
        assert context.step_md =~ "synthesize",
               "expected 'synthesize' instruction in step 3"

        assert context.step_md =~ "research",
               "expected 'research' as the basis for persona synthesis"

        {:ok, context}
      end
    end
  end

  defp response_text(%{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{text: t} -> t
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(%{text: text}), do: text
  defp response_text(other), do: inspect(other)
end
