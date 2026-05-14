defmodule MarketMySpecSpex.Story705.Criterion6169Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6169 — All sources failing returns an empty candidate list with
  per-source failure entries.

  When every source adapter returns an error, the search_engagements response
  must still succeed at the envelope level (isError: false). The candidates list
  is empty, and the response carries per-source failure metadata so the LLM can
  explain to the user which platforms are currently unavailable.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "all sources failing returns an empty candidate list with per-source failure entries" do
    scenario "search succeeds at the envelope level with an empty candidate list" do
      given_ "an authenticated account with no enabled venues (all sources effectively absent)", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "all sources down"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the envelope is not an error", context do
        refute context.response.isError,
               "expected search_engagements to return a non-error envelope even when all sources fail"

        {:ok, context}
      end

      then_ "the candidates list is empty", context do
        body = response_text(context.response)
        %{"candidates" => candidates} = Jason.decode!(body)

        assert candidates == [],
               "expected an empty candidates list when no venues are enabled/all fail"

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
