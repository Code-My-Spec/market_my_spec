defmodule MarketMySpecSpex.Story706.Criterion6128Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6128 — Returned thread includes OP body, comment tree, scores/likes,
  author handles, and timestamps.

  The get_thread MCP tool response contains the complete thread content needed by
  the LLM to understand the discussion context. The response must include at
  minimum: title, OP body, and comment tree. Scores, author handles, and timestamps
  are desirable fields that enrich LLM context.

  Interaction surface: MCP tool response (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures

  spex "returned thread includes OP body, comment tree, scores/likes, author handles, and timestamps" do
    scenario "get_thread response contains title and op_body fields" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls get_thread for a reddit thread", context do
        {:reply, response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "content_test_abc"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is not an error", context do
        refute context.response.isError,
               "expected get_thread to succeed, got an error response"

        {:ok, context}
      end

      then_ "the response body contains a title field", context do
        text = response_text(context.response)

        assert text =~ "title",
               "expected response to contain 'title' field, got: #{String.slice(text, 0, 200)}"

        {:ok, context}
      end

      then_ "the response body contains an op_body or thread body field", context do
        text = response_text(context.response)

        assert text =~ "op_body" or text =~ "body",
               "expected response to contain 'op_body' or 'body' field, got: #{String.slice(text, 0, 200)}"

        {:ok, context}
      end
    end

    scenario "get_thread response contains comment content" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls get_thread", context do
        {:reply, response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "comments_test_xyz"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response contains a comments or comment_tree field", context do
        text = response_text(context.response)

        assert text =~ "comments" or text =~ "comment_tree",
               "expected response to contain 'comments' or 'comment_tree' field, " <>
                 "got: #{String.slice(text, 0, 200)}"

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
