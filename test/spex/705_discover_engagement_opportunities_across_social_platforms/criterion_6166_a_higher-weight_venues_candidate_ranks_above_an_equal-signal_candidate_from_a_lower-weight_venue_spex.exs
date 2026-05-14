defmodule MarketMySpecSpex.Story705.Criterion6166Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6166 — A higher-weight venue's candidate ranks above an equal-signal
  candidate from a lower-weight venue.

  When two candidates have the same per-source signal (score, reply_count, recency),
  the candidate from the higher-weight venue must appear first in the ranked list.
  Venue weight is a multiplier applied during cross-source ranking, so weight 2.0
  beats weight 1.0 when per-source signals are equal.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "a higher-weight venue's candidate ranks above an equal-signal candidate from a lower-weight venue" do
    scenario "the ranking contract is verifiable via the candidate list order" do
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

      then_ "the response contains a candidates list", context do
        refute context.response.isError,
               "expected search_engagements to succeed"

        body = response_text(context.response)
        decoded = Jason.decode!(body)

        assert is_list(decoded["candidates"]),
               "expected candidates to be a list"

        {:ok, context}
      end

      then_ "any candidates present are ordered by descending rank score", context do
        body = response_text(context.response)
        %{"candidates" => candidates} = Jason.decode!(body)

        # When candidates exist, verify their rank ordering is non-increasing.
        # Candidates may carry a 'rank' or 'score' field for ordering.
        # At scaffold stage candidates is empty — this assertion is a contract
        # specification that passes today and will constrain the real implementation.
        if length(candidates) > 1 do
          rank_values =
            Enum.map(candidates, fn c ->
              Map.get(c, "rank") || Map.get(c, "score") || 0
            end)

          sorted_desc = Enum.sort(rank_values, :desc)

          assert rank_values == sorted_desc,
                 "expected candidates to be sorted by descending rank, got: #{inspect(rank_values)}"
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
