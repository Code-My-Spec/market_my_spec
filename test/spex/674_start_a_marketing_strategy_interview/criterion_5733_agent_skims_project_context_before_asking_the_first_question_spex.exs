defmodule MarketMySpecSpex.Story674.Criterion5733Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5733 — Agent skims project context before asking the first question

  The start_interview orientation must instruct the agent to check existing
  marketing artifacts and skim project context files (README.md, mix.exs,
  etc.) before asking any interview question.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "agent skims project context before asking the first question" do
    scenario "start_interview orientation includes Step 0 Orient with read-before-ask instructions" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation includes a Step 0 Orient section", context do
        assert context.orientation =~ "Step 0",
               "expected Step 0 in the orientation"

        assert context.orientation =~ "Orient",
               "expected Orient section in the orientation"

        {:ok, context}
      end

      then_ "the orient step instructs the agent to check for existing marketing artifacts", context do
        assert context.orientation =~ "Check whether `marketing/` already exists",
               "expected instruction to check for existing marketing/ artifacts"

        {:ok, context}
      end

      then_ "the orient step instructs skimming project context files", context do
        assert context.orientation =~ "README.md",
               "expected README.md mentioned in the orient step"

        assert context.orientation =~ "mix.exs",
               "expected mix.exs mentioned in the orient step"

        {:ok, context}
      end

      then_ "the orient step instructs reading before asking questions", context do
        assert context.orientation =~ "before asking",
               "expected 'before asking' read-before-ask instruction"

        assert context.orientation =~ "Don't make the user type things you can read",
               "expected the 'don't make the user type' instruction"

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
