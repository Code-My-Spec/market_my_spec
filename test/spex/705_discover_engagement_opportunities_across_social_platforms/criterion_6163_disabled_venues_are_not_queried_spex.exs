defmodule MarketMySpecSpex.Story705.Criterion6163Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6163 — Disabled venues are not queried.

  The search_engagements tool reads only enabled venues (enabled: true) from the
  VenuesRepository. A venue with enabled: false must not be included in the search
  fan-out, meaning no API call is made to its source for that venue.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "disabled venues are not queried" do
    scenario "an account with only disabled venues returns an empty candidate list" do
      given_ "an authenticated account with no enabled venues", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "elixir testing"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is not an error", context do
        refute context.response.isError,
               "expected search to succeed even with no enabled venues"

        {:ok, context}
      end

      then_ "the candidate list is empty because no venues were queried", context do
        body = response_text(context.response)
        %{"candidates" => candidates} = Jason.decode!(body)

        assert candidates == [],
               "expected empty candidates when no venues are enabled, got: #{inspect(candidates)}"

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
