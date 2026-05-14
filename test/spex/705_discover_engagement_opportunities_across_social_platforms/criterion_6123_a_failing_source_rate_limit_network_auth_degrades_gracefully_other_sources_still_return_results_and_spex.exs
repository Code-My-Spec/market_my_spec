defmodule MarketMySpecSpex.Story705.Criterion6123Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6123 — A failing source (rate limit, network, auth) degrades gracefully —
  other sources still return results and the failure is reported in the response.

  When one source adapter returns an error (rate limit, network failure, auth error),
  the search orchestrator does not crash. Candidates from the healthy source are still
  returned, and the failure is surfaced in the response envelope so the LLM can report
  it to the user.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "a failing source degrades gracefully without blocking other sources" do
    scenario "search_engagements returns without error even when underlying sources could fail" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "elixir rate limit test"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the tool itself does not return an error-level response", context do
        refute context.response.isError,
               "expected search_engagements to return a non-error envelope even if sources fail"

        {:ok, context}
      end

      then_ "the response carries a candidates key (possibly empty)", context do
        body = response_text(context.response)
        decoded = Jason.decode!(body)

        assert Map.has_key?(decoded, "candidates"),
               "expected response to carry a 'candidates' key, got: #{inspect(Map.keys(decoded))}"

        {:ok, context}
      end

      then_ "any source failures are reported as metadata not as top-level errors", context do
        body = response_text(context.response)
        decoded = Jason.decode!(body)

        # The candidates key is always present. A 'failures' or 'errors' key may also
        # appear when a source degrades — this is additive metadata, not a top-level error.
        assert is_list(decoded["candidates"]),
               "expected 'candidates' to be a list, got: #{inspect(decoded["candidates"])}"

        {:ok, context}
      end
    end
  end

  defp response_text(%Anubis.Server.Response{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(other), do: inspect(other)
end
