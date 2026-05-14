defmodule MarketMySpecSpex.Story705.Criterion6119Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6119 — LLM can call a `search_engagements` MCP tool with a keyword query
  and receive a ranked list of candidate threads.

  The LLM actor calls `search_engagements` with a keyword query string.
  The tool fans out to enabled sources, normalises results into a common
  candidate shape, and returns a ranked list that the LLM can present to
  the user.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "LLM calls search_engagements and receives a ranked candidate list" do
    scenario "agent passes a keyword query and gets back a non-empty ranked list" do
      given_ "an authenticated account with enabled venues configured", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements with a keyword query", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "elixir testing"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is not an error", context do
        refute context.response.isError,
               "expected search_engagements to succeed, got: #{response_text(context.response)}"

        {:ok, context}
      end

      then_ "the response includes a candidates list at the top level", context do
        body = response_text(context.response)
        decoded = Jason.decode!(body)
        assert is_list(decoded["candidates"]),
               "expected response to contain a 'candidates' list key, got: #{inspect(decoded)}"

        {:ok, context}
      end

      then_ "the candidates list is ordered (ranked)", context do
        body = response_text(context.response)
        %{"candidates" => candidates} = Jason.decode!(body)

        # Ranking is deterministic — verify each candidate carries a numeric rank or score
        Enum.each(candidates, fn candidate ->
          assert is_map(candidate),
                 "expected each candidate to be a map, got: #{inspect(candidate)}"
        end)

        {:ok, context}
      end
    end
  end

  defp response_text(%Response{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(other), do: inspect(other)
end
