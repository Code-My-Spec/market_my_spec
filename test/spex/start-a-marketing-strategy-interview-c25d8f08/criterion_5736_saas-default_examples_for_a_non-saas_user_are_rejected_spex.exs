defmodule MarketMySpecSpex.Story674.Criterion5736Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5736 — SaaS-default examples for a non-SaaS user are rejected

  Quality gate: the orientation delivered by start_interview must explicitly
  prohibit defaulting to dev-tool or SaaS framing, with a condition for when
  those examples are appropriate.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "SaaS-default examples quality gate" do
    scenario "start_interview orientation explicitly prohibits defaulting to SaaS or dev-tool framing" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation explicitly prohibits defaulting to dev-tool or SaaS examples", context do
        assert context.orientation =~ "Do not default to dev-tool, SaaS, or tech examples",
               "expected explicit prohibition against defaulting to dev-tool/SaaS examples"

        {:ok, context}
      end

      then_ "the prohibition includes a condition for when SaaS examples ARE appropriate", context do
        assert context.orientation =~ "unless the user's business is",
               "expected a condition clause permitting SaaS examples when appropriate"

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
