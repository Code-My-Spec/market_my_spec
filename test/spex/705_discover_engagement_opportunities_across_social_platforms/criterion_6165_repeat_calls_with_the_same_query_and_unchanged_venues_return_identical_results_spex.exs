defmodule MarketMySpecSpex.Story705.Criterion6165Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6165 — Repeat calls with the same query and unchanged venues return
  identical results.

  When the venue set and source data have not changed between two calls, the
  ranked candidate list returned by search_engagements is identical. The ranking
  algorithm is deterministic — it does not use random tie-breaking.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "repeat calls with the same query return identical results" do
    scenario "two identical calls in the same session return the same candidate lists" do
      given_ "an authenticated account-scoped user with a fixed session", context do
        scope = Fixtures.account_scoped_user_fixture()
        session_id = "spec-stable-#{System.unique_integer([:positive])}"

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: session_id}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "search_engagements is called twice with the identical query and frame", context do
        {:reply, first_response, _frame} =
          SearchEngagements.execute(%{query: "bdd testing elixir"}, context.frame)

        {:reply, second_response, _frame} =
          SearchEngagements.execute(%{query: "bdd testing elixir"}, context.frame)

        {:ok, Map.merge(context, %{first: first_response, second: second_response})}
      end

      then_ "both responses succeed", context do
        refute context.first.isError, "expected first call to succeed"
        refute context.second.isError, "expected second call to succeed"

        {:ok, context}
      end

      then_ "the candidate lists from both calls are identical", context do
        first_body = response_text(context.first)
        second_body = response_text(context.second)

        %{"candidates" => first_candidates} = Jason.decode!(first_body)
        %{"candidates" => second_candidates} = Jason.decode!(second_body)

        assert first_candidates == second_candidates,
               "expected repeat calls to return identical candidate lists (deterministic ranking)"

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
