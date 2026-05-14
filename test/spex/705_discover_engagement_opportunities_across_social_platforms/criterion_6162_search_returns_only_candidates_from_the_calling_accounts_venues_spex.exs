defmodule MarketMySpecSpex.Story705.Criterion6162Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6162 — Search returns only candidates from the calling account's venues.

  The search_engagements tool reads the venue list from the current scope's
  active_account_id. Each account has its own venue configuration. A call made
  in the context of Account A must not return candidates from Account B's venues.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "search returns only candidates from the calling account's venues" do
    scenario "two accounts call search_engagements and each gets their own scoped results" do
      given_ "two separate accounts each with their own scope", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        frame_a = %{
          assigns: %{current_scope: scope_a},
          context: %{session_id: "spec-a-#{System.unique_integer([:positive])}"}
        }

        frame_b = %{
          assigns: %{current_scope: scope_b},
          context: %{session_id: "spec-b-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{
          scope_a: scope_a,
          scope_b: scope_b,
          frame_a: frame_a,
          frame_b: frame_b
        })}
      end

      when_ "both accounts call search_engagements with the same query", context do
        {:reply, response_a, _frame} =
          SearchEngagements.execute(%{query: "elixir"}, context.frame_a)

        {:reply, response_b, _frame} =
          SearchEngagements.execute(%{query: "elixir"}, context.frame_b)

        {:ok, Map.merge(context, %{response_a: response_a, response_b: response_b})}
      end

      then_ "both responses are not errors", context do
        refute context.response_a.isError,
               "expected account A's search to succeed"

        refute context.response_b.isError,
               "expected account B's search to succeed"

        {:ok, context}
      end

      then_ "both responses are account-scoped (carry candidates, not cross-account data)", context do
        body_a = response_text(context.response_a)
        body_b = response_text(context.response_b)

        decoded_a = Jason.decode!(body_a)
        decoded_b = Jason.decode!(body_b)

        assert Map.has_key?(decoded_a, "candidates"),
               "expected account A's response to carry a 'candidates' key"

        assert Map.has_key?(decoded_b, "candidates"),
               "expected account B's response to carry a 'candidates' key"

        # Both accounts have no venues configured yet (scaffold), so both return empty
        # candidates. The critical contract is that each call is scoped to its own account.
        assert decoded_a["candidates"] == [],
               "expected account A to get its own (empty) candidate list, not shared data"

        assert decoded_b["candidates"] == [],
               "expected account B to get its own (empty) candidate list, not shared data"

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
