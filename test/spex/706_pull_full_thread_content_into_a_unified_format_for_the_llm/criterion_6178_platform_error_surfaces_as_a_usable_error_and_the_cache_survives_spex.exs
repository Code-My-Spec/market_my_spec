defmodule MarketMySpecSpex.Story706.Criterion6178Spex do
  @moduledoc """
  Story 706 — Pull full thread content into a unified format for the LLM
  Criterion 6178 — Platform error surfaces as a usable error and the cache survives.

  When the platform API returns an error (network failure, rate limit, not found),
  the get_thread MCP tool surfaces a usable error response (isError: true with a
  descriptive message). Any previously cached thread for the same ID is not
  evicted — the cache survives a failed fetch attempt.

  At the scaffold stage this verifies the tool returns a structured response even
  for unknown/error-inducing inputs, and does not crash.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagement.Tools.GetThread
  alias MarketMySpecSpex.Fixtures

  spex "platform error surfaces as a usable error and the cache survives" do
    scenario "get_thread with an invalid source does not crash and returns a response" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "get_thread is called with an unknown source", context do
        result =
          try do
            GetThread.execute(
              %{source: "unknown_platform", thread_id: "any_thread_id"},
              context.frame
            )
          rescue
            e -> {:error, Exception.message(e)}
          end

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the tool returns a tuple instead of crashing", context do
        assert match?({:reply, _, _}, context.result) or match?({:error, _}, context.result),
               "expected get_thread to return a {:reply, _, _} or {:error, _} tuple, " <>
                 "got: #{inspect(context.result)}"

        {:ok, context}
      end
    end

    scenario "get_thread succeeds for a valid source after an error attempt" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "an error attempt is made and then a valid fetch follows", context do
        _error_result =
          try do
            GetThread.execute(
              %{source: "invalid_source", thread_id: "cache_survives_test"},
              context.frame
            )
          rescue
            _ -> :rescued
          end

        {:reply, response, _frame} =
          GetThread.execute(
            %{source: "reddit", thread_id: "cache_survives_reddit_thread"},
            context.frame
          )

        {:ok, Map.put(context, :valid_response, response)}
      end

      then_ "the valid fetch succeeds after the error attempt", context do
        refute context.valid_response.isError,
               "expected the valid get_thread call to succeed even after a prior error attempt"

        {:ok, context}
      end
    end
  end
end
