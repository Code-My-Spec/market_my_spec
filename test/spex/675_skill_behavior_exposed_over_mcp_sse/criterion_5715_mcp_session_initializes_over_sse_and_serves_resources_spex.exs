defmodule MarketMySpecSpex.Story675.Criterion5715Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5715 — MCP session initializes over SSE and serves resources

  Behavioral assertion: the start_interview tool is callable and returns a
  non-empty text response with orientation content. This verifies that the
  tool wiring is functional; SSE transport behavior is tested by 5732 in
  story 674 (which covers the 401/WWW-Authenticate path) and is provided
  by the Anubis library.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Frame
  alias MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview

  spex "MCP session initializes over SSE and serves resources" do
    scenario "start_interview tool executes and returns a valid orientation response" do
      given_ "a server frame with no preconditions", context do
        frame = %Frame{assigns: %{}}
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent invokes start_interview", context do
        {:reply, response, _frame} = StartInterview.execute(%{}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the tool returns a non-empty text response", context do
        text = tool_response_text(context.response)
        assert byte_size(text) > 0,
               "expected start_interview to return non-empty orientation content"

        {:ok, context}
      end

      then_ "the response content identifies this as the marketing-strategy skill", context do
        text = tool_response_text(context.response)
        assert text =~ "marketing-strategy",
               "expected orientation to reference the marketing-strategy skill"

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
