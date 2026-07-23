defmodule MarketMySpecSpex.Story674.Criterion5738Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5738 — Batched end-of-run artifact writes are rejected

  Quality gate: the orientation delivered by start_interview must explicitly
  forbid batching artifact writes to the end of the run, and include the
  rationale about bailing users retaining three usable files.

  Surface: `StartInterview.execute/2` tool module called directly with a Frame.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "batched artifact writes quality gate" do
    scenario "start_interview orientation explicitly forbids batching artifact writes" do
      given_ "no preconditions — the tool needs only a frame", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :orientation, response_text(response))}
      end

      then_ "the orientation explicitly says do not batch writes", context do
        assert context.orientation =~ "don't batch",
               "expected 'don't batch' in the orientation"

        {:ok, context}
      end

      then_ "the no-batch rule includes the rationale about bailing users", context do
        assert context.orientation =~ "don't batch",
               "expected the no-batch rule to appear in the orientation"

        assert context.orientation =~ "three usable files",
               "expected the 'three usable files' rationale for the no-batch rule"

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
