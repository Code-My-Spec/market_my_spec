defmodule MarketMySpecSpex.Story674.Criterion5742Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5742 — Agent silently produces a 40-slide deck or sets up analytics is rejected

  Quality gate: the orientation delivered by start_interview must explicitly rule
  out producing presentation decks and setting up analytics/tooling. These scope
  boundaries must be in the 'What this skill does NOT do' section.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "40-slide deck and analytics setup quality gate" do
    scenario "start_interview orientation explicitly prohibits deck production and analytics setup" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation explicitly rules out producing a slide deck", context do
        assert context.orientation =~ "What this skill does NOT do",
               "expected 'What this skill does NOT do' scope boundary section"

        assert context.orientation =~ "40-slide",
               "expected '40-slide' in the scope exclusions"

        {:ok, context}
      end

      then_ "the orientation explicitly rules out analytics and tooling setup", context do
        assert context.orientation =~ "What this skill does NOT do",
               "expected 'What this skill does NOT do' scope boundary section"

        assert context.orientation =~ "analytics",
               "expected 'analytics' in the scope exclusions"

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
