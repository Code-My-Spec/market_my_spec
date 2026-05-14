defmodule MarketMySpecSpex.Story706.Criterion6176Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6176 — Repeat fetch within the freshness window returns cached.

  Calling get_thread twice for the same (source, thread_id) pair in rapid
  succession returns identical content without triggering a second platform
  API call. The freshness window prevents redundant fetches within the same
  agent session.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures

  spex "repeat fetch within the freshness window returns cached" do
    scenario "two consecutive get_thread calls with the same ID return identical content" do
      given_ "an authenticated account-scoped user with a stable session frame", context do
        scope = Fixtures.account_scoped_user_fixture()
        session_id = "spec-freshness-#{System.unique_integer([:positive])}"

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: session_id}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent fetches the same thread twice in succession", context do
        thread_id = "freshness_window_test_thread_111"

        {:reply, first_response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: thread_id},
            context.frame
          )

        {:reply, second_response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: thread_id},
            context.frame
          )

        {:ok,
         Map.merge(context, %{
           first: first_response,
           second: second_response,
           thread_id: thread_id
         })}
      end

      then_ "both fetches succeed without error", context do
        refute context.first.isError, "expected first fetch to succeed"
        refute context.second.isError, "expected second fetch to succeed"
        {:ok, context}
      end

      then_ "both responses contain identical content", context do
        first_text = response_text(context.first)
        second_text = response_text(context.second)

        assert first_text == second_text,
               "expected repeat fetch to return cached (identical) content, " <>
                 "but responses differed"

        {:ok, context}
      end

      then_ "the response references the originally requested thread ID", context do
        text = response_text(context.first)

        assert text =~ context.thread_id,
               "expected response to echo the thread_id '#{context.thread_id}'"

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
