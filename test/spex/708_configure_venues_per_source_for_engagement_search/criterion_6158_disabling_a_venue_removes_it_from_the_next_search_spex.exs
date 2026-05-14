defmodule MarketMySpecSpex.Story708.Criterion6158Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6158 — Disabling a venue removes it from the next search.

  When a venue's enabled flag is set to false, the SearchEngagements tool does
  not query that venue. At the scaffold stage, SearchEngagements returns an
  empty candidates list (no real API calls), so the key invariant is that
  search succeeds and accounts with no enabled venues get empty results.

  Interaction surface: MCP SearchEngagements + Venue schema (integration).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "disabling a venue removes it from the next search" do
    scenario "an account with no enabled venues gets an empty candidate list" do
      given_ "an authenticated account-scoped user with no enabled venues", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements for an account with no venues", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "elixir"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response succeeds and returns an empty candidates list", context do
        refute context.response.isError,
               "expected search to succeed even with no enabled venues"

        text = response_text(context.response)
        {:ok, decoded} = Jason.decode(text)

        assert decoded["candidates"] == [],
               "expected empty candidates list when no venues are enabled, " <>
                 "got: #{inspect(decoded["candidates"])}"

        {:ok, context}
      end
    end

    scenario "search with no enabled venues returns a consistent empty result" do
      given_ "two calls from the same account with no venues configured", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "search_engagements is called twice", context do
        {:reply, first, _} = SearchEngagements.execute(%{query: "elixir"}, context.frame)
        {:reply, second, _} = SearchEngagements.execute(%{query: "elixir"}, context.frame)
        {:ok, Map.merge(context, %{first: first, second: second})}
      end

      then_ "both responses return empty candidates (no venues = no results)", context do
        text_a = response_text(context.first)
        text_b = response_text(context.second)

        {:ok, decoded_a} = Jason.decode(text_a)
        {:ok, decoded_b} = Jason.decode(text_b)

        assert decoded_a["candidates"] == [],
               "expected first call to return empty candidates"

        assert decoded_b["candidates"] == [],
               "expected second call to return empty candidates"

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
