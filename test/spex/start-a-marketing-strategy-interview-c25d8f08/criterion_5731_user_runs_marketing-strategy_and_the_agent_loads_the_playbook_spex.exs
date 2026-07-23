defmodule MarketMySpecSpex.Story674.Criterion5731Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5731 — User runs /marketing-strategy and the agent loads the playbook

  The start_interview tool must return an orientation that names the skill,
  describes the 8-step flow, and lists the step resource URIs so the agent
  can load them progressively.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "user runs /marketing-strategy and the agent loads the playbook" do
    scenario "start_interview returns an orientation naming the skill and listing 8 step URIs" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview with no arguments", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation identifies the skill as marketing-strategy", context do
        assert context.orientation =~ "name: marketing-strategy",
               "expected the orientation to identify the skill as marketing-strategy"

        {:ok, context}
      end

      then_ "the orientation describes an 8-step guided flow", context do
        assert context.orientation =~ "8-step",
               "expected the orientation to mention the 8-step flow"

        {:ok, context}
      end

      then_ "the orientation includes Step 0 Orient", context do
        assert context.orientation =~ "Step 0",
               "expected the orientation to include Step 0"

        {:ok, context}
      end

      then_ "the orientation lists step resource URIs for all 8 steps", context do
        assert context.orientation =~ "marketing-strategy://steps/01_current_state",
               "expected step 1 resource URI in the orientation"

        assert context.orientation =~ "marketing-strategy://steps/08_plan",
               "expected step 8 resource URI in the orientation"

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
