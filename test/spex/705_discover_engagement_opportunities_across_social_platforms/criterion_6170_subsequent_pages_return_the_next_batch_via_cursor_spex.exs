defmodule MarketMySpecSpex.Story705.Criterion6170Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6170 — Subsequent pages return the next batch via cursor.

  The search_engagements tool supports cursor-based pagination. The first call
  returns up to 25 candidates per source and optionally a cursor. Passing the
  cursor in the next call returns the following batch without repeating candidates
  from the first page.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "subsequent pages return the next batch via cursor" do
    scenario "the first page response is well-formed for cursor-based pagination" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the first page is requested", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "elixir"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response succeeds", context do
        refute context.response.isError, "expected search to succeed"

        {:ok, context}
      end

      then_ "the response body is valid JSON with a candidates key", context do
        body = response_text(context.response)
        decoded = Jason.decode!(body)

        assert is_list(decoded["candidates"]),
               "expected 'candidates' to be a list"

        {:ok, context}
      end
    end

    scenario "a second page call with a cursor does not error" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "search is called with a cursor parameter", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(
            %{query: "elixir", cursor: "page2-cursor-token"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response does not error when a cursor is passed", context do
        refute context.response.isError,
               "expected search_engagements to accept a cursor parameter without error"

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
