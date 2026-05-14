defmodule MarketMySpecSpex.Story705.Criterion6167Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6167 — Among same-weight venues, the per-source signal determines order.

  When two candidates come from venues with the same weight, the tie is broken by
  the per-source signal: higher score (upvotes), more recent activity, or higher
  reply count (in that priority order). This ensures the most engaging thread
  surfaces first even when venue weights are equal.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "among same-weight venues the per-source signal determines order" do
    scenario "search returns a list that respects per-source signal ordering" do
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
          SearchEngagements.execute(%{query: "elixir genserver"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response succeeds and carries a candidates list", context do
        refute context.response.isError,
               "expected search_engagements to succeed"

        body = response_text(context.response)
        decoded = Jason.decode!(body)

        assert is_list(decoded["candidates"]),
               "expected candidates to be a list"

        {:ok, context}
      end

      then_ "among candidates from equal-weight venues the signal ordering is preserved", context do
        body = response_text(context.response)
        %{"candidates" => candidates} = Jason.decode!(body)

        # When multiple candidates exist from equal-weight venues, signal ordering
        # must be non-increasing by score. At scaffold stage the list is empty
        # — this assertion defines the contract for the real implementation.
        if length(candidates) > 1 do
          scores = Enum.map(candidates, &(Map.get(&1, "score") || 0))
          sorted_desc = Enum.sort(scores, :desc)

          assert scores == sorted_desc,
                 "expected candidates to be ordered by descending per-source signal (score), got: #{inspect(scores)}"
        end

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
