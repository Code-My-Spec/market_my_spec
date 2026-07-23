defmodule MarketMySpecSpex.Story674.Criterion5737Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5737 — User bails after step 3 and finds three usable artifacts on disk

  The runtime behavior (the agent actually writes files as it goes) is LLM-driven
  and not deterministically testable at the server level. What IS testable: the
  orientation and agent operating rules delivered by start_interview must instruct
  incremental writes with the rationale about bailing users.

  This spec tests the deterministic precondition (the playbook instruction
  and the operating rules injected by the tool), not LLM runtime execution.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "incremental artifact writes are required after each step" do
    scenario "start_interview orientation instructs writing artifacts as each step completes" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation instructs writing artifacts incrementally, not batched", context do
        assert context.orientation =~ "don't batch",
               "expected 'don't batch' instruction in the orientation"

        assert context.orientation =~ "If the user bails after step 3",
               "expected the bail-after-step-3 rationale in the orientation"

        {:ok, context}
      end

      then_ "the orientation specifies the artifact path for the first three steps", context do
        assert context.orientation =~ "marketing/01_current_state.md",
               "expected step 1 artifact path in the orientation"

        assert context.orientation =~ "marketing/02_jobs_and_segments.md",
               "expected step 2 artifact path in the orientation"

        assert context.orientation =~ "marketing/03_personas.md",
               "expected step 3 artifact path in the orientation"

        {:ok, context}
      end

      then_ "the agent operating rules injected by the tool repeat the no-batch rule", context do
        assert context.orientation =~ "don't batch",
               "expected the no-batch rule in the agent operating rules section"

        assert context.orientation =~ "Write artifacts as you go",
               "expected 'Write artifacts as you go' instruction"

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
