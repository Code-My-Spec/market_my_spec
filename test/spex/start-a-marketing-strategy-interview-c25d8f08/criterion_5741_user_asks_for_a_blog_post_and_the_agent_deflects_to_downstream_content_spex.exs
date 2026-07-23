defmodule MarketMySpecSpex.Story674.Criterion5741Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5741 — User asks for a blog post and the agent deflects to downstream content

  The runtime deflection behavior is LLM-driven and not deterministically testable
  at the server level. What IS testable: the orientation delivered by start_interview
  must define the scope boundary excluding blog posts and downstream content work,
  AND the agent operating rules must instruct the agent to deflect such requests.

  This spec tests the deterministic precondition (the scope boundary instruction and
  operating rules), not the LLM's actual deflection behavior.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "skill deflects blog post requests to downstream content work" do
    scenario "start_interview orientation defines scope boundary excluding blog post creation" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation defines a scope boundary excluding blog post creation", context do
        assert context.orientation =~ "What this skill does NOT do",
               "expected 'What this skill does NOT do' scope boundary section"

        assert context.orientation =~ "blog posts",
               "expected 'blog posts' in the scope exclusions"

        {:ok, context}
      end

      then_ "the exclusion frames blog posts as downstream content work", context do
        assert context.orientation =~ "downstream content",
               "expected 'downstream content' framing in the scope exclusions"

        {:ok, context}
      end

      then_ "the agent operating rules injected by the tool instruct deflection", context do
        assert context.orientation =~ "Deflect downstream content requests",
               "expected deflection instruction in the agent operating rules"

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
