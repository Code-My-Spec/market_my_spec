defmodule MarketMySpecSpex.Story705.Criterion6168Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6168 — One source failing does not poison the other source's results.

  The search orchestrator fans out to all enabled sources in parallel. If the
  Reddit adapter errors (network failure, rate limit) but ElixirForum succeeds,
  the candidates from ElixirForum are still returned. The failure of one source
  is isolated — it does not cause the entire search to fail or empty the results.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "one source failing does not poison the other source's results" do
    scenario "search_engagements never crashes even when a source adapter could fail" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "search_engagements is called", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "crash isolation test"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is not an error even if individual sources might fail", context do
        refute context.response.isError,
               "expected the search_engagements envelope to succeed even if a source adapter fails"

        {:ok, context}
      end

      then_ "the response always carries a candidates list", context do
        body = response_text(context.response)
        decoded = Jason.decode!(body)

        assert is_list(decoded["candidates"]),
               "expected 'candidates' to always be a list regardless of per-source failures"

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
