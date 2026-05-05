defmodule MarketMySpecSpex.Story674.Criterion5734Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5734 — Skipping orient and asking interview questions cold is rejected

  Quality gate: the orientation delivered by start_interview must place the
  Step 0 Orient section BEFORE the 8-step table. A playbook that jumps to
  interview steps without orienting first fails this spec.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "orient step quality gate" do
    scenario "start_interview orientation places Step 0 Orient before the 8-step table" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation defines the Step 0 Orient section before the 8-step table", context do
        # Use section headings (## prefix) to find the section positions, not first prose mentions
        orient_pos = :binary.match(context.orientation, "## Step 0")
        steps_pos = :binary.match(context.orientation, "## The 8 steps")

        assert orient_pos != :nomatch,
               "expected '## Step 0' section heading to appear in the orientation"

        assert steps_pos != :nomatch,
               "expected '## The 8 steps' section heading to appear in the orientation"

        {orient_offset, _} = orient_pos
        {steps_offset, _} = steps_pos

        assert orient_offset < steps_offset,
               "expected the ## Step 0 section to appear before the ## The 8 steps section"

        {:ok, context}
      end

      then_ "the orientation instructs the agent to check context before asking anything", context do
        assert context.orientation =~ "Before touching anything",
               "expected 'Before touching anything' instruction in the orientation"

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
