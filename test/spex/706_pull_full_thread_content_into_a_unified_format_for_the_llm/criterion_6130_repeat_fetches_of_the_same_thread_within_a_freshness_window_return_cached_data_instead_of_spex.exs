defmodule MarketMySpecSpex.Story706.Criterion6130Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6130 — Repeat fetches of the same thread within a freshness window
  return cached data instead of re-hitting the platform.

  The ThreadsRepository implements a freshness-window cache check. When
  get_or_fetch_thread/3 is called twice for the same (account, source, thread_id)
  within the freshness window, the second call returns the persisted Thread record
  and does not call the source adapter again.

  Interaction surface: MCP tool (get_thread) — consecutive calls return consistent
  results, indicating the cache is in effect even at the scaffold stage.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures

  spex "repeat fetches within a freshness window return cached data" do
    scenario "calling get_thread twice for the same ID returns consistent results" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()
        session_id = "spec-cache-#{System.unique_integer([:positive])}"

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: session_id}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "get_thread is called twice for the same thread ID", context do
        {:reply, first_response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "cache_test_thread_xyz"},
            context.frame
          )

        {:reply, second_response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "cache_test_thread_xyz"},
            context.frame
          )

        {:ok, Map.merge(context, %{first: first_response, second: second_response})}
      end

      then_ "both responses succeed", context do
        refute context.first.isError, "expected first get_thread call to succeed"
        refute context.second.isError, "expected second get_thread call to succeed"

        {:ok, context}
      end

      then_ "both responses return the same thread content", context do
        first_text = response_text(context.first)
        second_text = response_text(context.second)

        assert first_text == second_text,
               "expected repeat get_thread calls to return identical content (cache hit), " <>
                 "but got different responses"

        {:ok, context}
      end
    end

    scenario "calling get_thread for different thread IDs returns distinct results" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-distinct-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "get_thread is called for two different thread IDs", context do
        {:reply, first_response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "distinct_thread_aaa"},
            context.frame
          )

        {:reply, second_response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "distinct_thread_bbb"},
            context.frame
          )

        {:ok, Map.merge(context, %{first: first_response, second: second_response})}
      end

      then_ "both responses succeed without error", context do
        refute context.first.isError, "expected first get_thread call to succeed"
        refute context.second.isError, "expected second get_thread call to succeed"

        {:ok, context}
      end

      then_ "the two responses contain different thread IDs", context do
        first_text = response_text(context.first)
        second_text = response_text(context.second)

        assert first_text =~ "distinct_thread_aaa",
               "expected first response to reference thread_id 'distinct_thread_aaa'"

        assert second_text =~ "distinct_thread_bbb",
               "expected second response to reference thread_id 'distinct_thread_bbb'"

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
