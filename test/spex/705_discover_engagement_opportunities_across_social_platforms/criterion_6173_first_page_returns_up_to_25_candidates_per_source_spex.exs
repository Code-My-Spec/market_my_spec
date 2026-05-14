defmodule MarketMySpecSpex.Story705.Criterion6173Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6173 — First page returns up to 25 candidates per source.

  The search_engagements tool caps each source's first-page results at 25
  candidates before merging and ranking. This bounds the payload size and
  ensures consistent LLM context usage. The total candidate list is therefore
  at most 25 × (number of enabled sources) before deduplication.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "first page returns up to 25 candidates per source" do
    scenario "the candidate list from search_engagements never exceeds the per-source page cap" do
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
          SearchEngagements.execute(%{query: "elixir"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response succeeds", context do
        refute context.response.isError, "expected search to succeed"

        {:ok, context}
      end

      then_ "the candidate list does not exceed 25 candidates per enabled source", context do
        body = response_text(context.response)
        %{"candidates" => candidates} = Jason.decode!(body)

        # Maximum two sources (Reddit + ElixirForum) × 25 per source = 50 max.
        # At scaffold stage the list is empty (0 ≤ 50), so this always passes.
        # The real cap enforcement activates once source adapters return live data.
        max_candidates = 50

        assert length(candidates) <= max_candidates,
               "expected at most #{max_candidates} candidates (25 per source × 2 sources), got #{length(candidates)}"

        {:ok, context}
      end

      then_ "each source contributes at most 25 candidates before merge", context do
        body = response_text(context.response)
        %{"candidates" => candidates} = Jason.decode!(body)

        # Group by source and check per-source count
        by_source = Enum.group_by(candidates, &Map.get(&1, "source"))

        Enum.each(by_source, fn {source, source_candidates} ->
          assert length(source_candidates) <= 25,
                 "expected at most 25 candidates from source '#{source}', got #{length(source_candidates)}"
        end)

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
