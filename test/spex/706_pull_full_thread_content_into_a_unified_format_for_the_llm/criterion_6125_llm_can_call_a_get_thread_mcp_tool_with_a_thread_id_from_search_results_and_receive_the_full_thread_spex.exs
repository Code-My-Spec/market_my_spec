defmodule MarketMySpecSpex.Story706.Criterion6125Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6125 — LLM can call a `get_thread` MCP tool with a thread ID from search results and receive the full thread

  The LLM receives a thread ID from a prior search result and calls get_thread.
  The tool must return a structured response containing the thread's full content:
  title, OP body, comment tree, scores, author handles, and timestamps.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures

  spex "LLM calls get_thread MCP tool with a thread ID and receives full thread" do
    scenario "agent submits a reddit thread ID and gets back a normalized thread response" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls get_thread with a reddit thread ID", context do
        {:reply, response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "test_thread_abc123"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response contains the full thread content", context do
        refute context.response.isError,
               "expected get_thread to return a successful response, not an error"

        text = response_text(context.response)

        assert text =~ ~r/title/i or text =~ ~r/op_body/i or text =~ ~r/thread/i,
               "expected response to contain thread content fields"

        {:ok, context}
      end
    end
  end

  defp response_text(%{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(other), do: inspect(other)
end
