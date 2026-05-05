defmodule MarketMySpecSpex.Story674.Criterion5735Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5735 — Restaurant owner gets restaurant examples and one-question cadence

  The runtime behavior (LLM adapts examples to the user's domain) is not
  deterministically testable at the server level. What IS testable: the
  orientation delivered by start_interview must instruct the agent to adapt
  examples, name non-software business types, and enforce one-question cadence.

  This spec tests the deterministic precondition (the playbook instruction),
  not the runtime LLM output.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "skill adapts examples to the user's business type and uses one-question cadence" do
    scenario "start_interview orientation is industry-agnostic and enforces single-question pace" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation covers non-software business types explicitly", context do
        assert context.orientation =~ "restaurant",
               "expected 'restaurant' as an example business type in the orientation"

        assert context.orientation =~ "local business",
               "expected 'local business' as an example in the orientation"

        {:ok, context}
      end

      then_ "the orientation instructs one or two questions at a time", context do
        assert context.orientation =~ "one or two questions at a time",
               "expected 'one or two questions at a time' cadence instruction"

        {:ok, context}
      end

      then_ "the orientation instructs adapting examples to the user's business type", context do
        assert context.orientation =~ "Adapt to the business type",
               "expected 'Adapt to the business type' instruction"

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
