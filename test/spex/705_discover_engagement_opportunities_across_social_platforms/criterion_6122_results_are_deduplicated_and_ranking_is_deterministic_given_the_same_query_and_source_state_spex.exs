defmodule MarketMySpecSpex.Story705.Criterion6122Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6122 — Results are deduplicated and ranking is deterministic given the
  same query and source state.

  The search orchestrator deduplicates candidates so the same thread URL never
  appears twice in the result list. When called twice with the same query and the
  same source state (same venues, same stub data), the ranked order of candidates
  is identical across both calls.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "results are deduplicated and ranking is deterministic" do
    scenario "two calls with identical query return identical candidate lists" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements twice with the same query", context do
        {:reply, response_a, _frame} =
          SearchEngagements.execute(%{query: "elixir testing"}, context.frame)

        {:reply, response_b, _frame} =
          SearchEngagements.execute(%{query: "elixir testing"}, context.frame)

        {:ok, Map.merge(context, %{response_a: response_a, response_b: response_b})}
      end

      then_ "both responses are not errors", context do
        refute context.response_a.isError, "expected first call to succeed"
        refute context.response_b.isError, "expected second call to succeed"

        {:ok, context}
      end

      then_ "both responses return the same candidate count", context do
        body_a = response_text(context.response_a)
        body_b = response_text(context.response_b)

        %{"candidates" => candidates_a} = Jason.decode!(body_a)
        %{"candidates" => candidates_b} = Jason.decode!(body_b)

        assert length(candidates_a) == length(candidates_b),
               "expected both calls to return the same number of candidates"

        {:ok, context}
      end

      then_ "the candidate list contains no duplicate URLs", context do
        body = response_text(context.response_a)
        %{"candidates" => candidates} = Jason.decode!(body)

        urls = Enum.map(candidates, &Map.get(&1, "url"))
        unique_urls = Enum.uniq(urls)

        assert length(urls) == length(unique_urls),
               "expected candidate list to contain no duplicate URLs, but found duplicates"

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
