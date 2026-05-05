defmodule MarketMySpecSpex.Story675.Criterion5723Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5723 — Agent invokes marketing-strategy and receives SKILL.md

  The start_interview tool returns the SKILL.md orientation document when
  invoked. This is tested at the tool module level using Frame.execute,
  which is sufficient: if the tool returns the correct content, the MCP
  wire layer (handled by Anubis) will deliver it to any connected agent.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "agent invokes marketing-strategy and receives SKILL.md" do
    scenario "start_interview returns the SKILL.md orientation document" do
      given_ "a server frame with no preconditions", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview for marketing-strategy", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, tool_response_text(response))}
      end

      then_ "the response contains the SKILL.md orientation content", context do
        assert context.orientation =~ "name: marketing-strategy",
               "expected orientation to contain 'name: marketing-strategy'"

        {:ok, context}
      end

      then_ "the orientation content references the eight step files", context do
        assert context.orientation =~ "steps/01_current_state",
               "expected orientation to reference step 01"

        assert context.orientation =~ "steps/08_plan",
               "expected orientation to reference step 08"

        {:ok, context}
      end
    end
  end

  # Tool responses have content: [%{"text" => ..., "type" => "text"}]
  defp tool_response_text(%{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
  end

  defp tool_response_text(other), do: inspect(other)
end
