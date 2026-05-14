defmodule MarketMySpecSpex.Story706.Criterion6174Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6174 — Agent fetches a Reddit thread by ID.

  The LLM agent calls the get_thread MCP tool with source="reddit" and a
  thread ID. The tool returns a structured response with the thread content.
  This is the primary happy-path scenario for Story 706.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures

  spex "agent fetches a Reddit thread by ID" do
    scenario "agent calls get_thread with source=reddit and receives a thread response" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls get_thread with a Reddit thread ID", context do
        {:reply, response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "reddit_thread_t3_abc99"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is not an error", context do
        refute context.response.isError,
               "expected get_thread to return a successful response"

        {:ok, context}
      end

      then_ "the response body is valid JSON", context do
        text = response_text(context.response)

        assert {:ok, _decoded} = Jason.decode(text),
               "expected response body to be valid JSON, got: #{String.slice(text, 0, 300)}"

        {:ok, context}
      end

      then_ "the decoded response contains the thread_id", context do
        text = response_text(context.response)
        {:ok, decoded} = Jason.decode(text)

        assert decoded["thread_id"] == "reddit_thread_t3_abc99" or
                 decoded["id"] == "reddit_thread_t3_abc99" or
                 text =~ "reddit_thread_t3_abc99",
               "expected response to echo the thread_id, got: #{inspect(decoded)}"

        {:ok, context}
      end

      then_ "the decoded response identifies the source as reddit", context do
        text = response_text(context.response)
        {:ok, decoded} = Jason.decode(text)

        assert decoded["source"] == "reddit",
               "expected response source to be 'reddit', got: #{inspect(decoded["source"])}"

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
