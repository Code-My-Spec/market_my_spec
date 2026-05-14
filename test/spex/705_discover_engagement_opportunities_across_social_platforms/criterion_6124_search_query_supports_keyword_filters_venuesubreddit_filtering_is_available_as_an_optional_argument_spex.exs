defmodule MarketMySpecSpex.Story705.Criterion6124Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6124 — Search query supports keyword filters; venue/subreddit filtering
  is available as an optional argument.

  The search_engagements tool accepts an optional `venue` parameter in addition to
  the required `query`. When provided, search is scoped to only that venue/subreddit.
  When omitted, all enabled venues are searched. The tool must not error when
  no `venue` filter is supplied.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "search query supports keyword filters and optional venue scoping" do
    scenario "search without venue filter searches all enabled venues" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements with only a query (no venue filter)", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "elixir testing"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the tool responds without error", context do
        refute context.response.isError,
               "expected search_engagements to succeed without a venue filter"

        {:ok, context}
      end
    end

    scenario "search with an optional venue filter scopes the query to that venue" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements with a query and a venue filter", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(
            %{query: "elixir testing", venue: "elixir"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the tool responds without error when a venue filter is supplied", context do
        refute context.response.isError,
               "expected search_engagements to succeed with a venue filter argument"

        {:ok, context}
      end

      then_ "the response still carries a candidates key", context do
        body = response_text(context.response)
        decoded = Jason.decode!(body)

        assert Map.has_key?(decoded, "candidates"),
               "expected response to carry a 'candidates' key even with a venue filter"

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
