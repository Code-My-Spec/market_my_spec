defmodule MarketMySpecSpex.Story705.Criterion6121Spex do
  @moduledoc """
  Story 705 — Discover engagement opportunities across social platforms
  Criterion 6121 — Each result includes title, source, URL, score/upvotes, reply count,
  recency, and a snippet.

  Every candidate in the search_engagements response carries a common shape:
  title, source, url, score (upvotes or equivalent), reply_count, recency (last
  activity timestamp), and a text snippet. This shape is source-agnostic so the
  LLM can render a unified list regardless of which platform the thread comes from.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "each result includes the required candidate fields" do
    scenario "search response envelope documents the expected candidate shape" do
      given_ "an authenticated account-scoped user", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the LLM calls search_engagements", context do
        {:reply, response, _frame} =
          SearchEngagements.execute(%{query: "elixir phoenix"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is not an error", context do
        refute context.response.isError,
               "expected search_engagements to return a non-error response"

        {:ok, context}
      end

      then_ "the response body is valid JSON with a candidates key", context do
        body = response_text(context.response)
        decoded = Jason.decode!(body)

        assert Map.has_key?(decoded, "candidates"),
               "expected response JSON to have a 'candidates' key, got keys: #{inspect(Map.keys(decoded))}"

        {:ok, context}
      end

      then_ "each candidate in the list carries the required shape fields", context do
        body = response_text(context.response)
        %{"candidates" => candidates} = Jason.decode!(body)

        # When candidates are present they must each carry the required shape.
        # At scaffold stage the list may be empty — assert shape on any that exist.
        Enum.each(candidates, fn candidate ->
          required_keys = ~w(title source url score reply_count recency snippet)

          Enum.each(required_keys, fn key ->
            assert Map.has_key?(candidate, key),
                   "expected candidate to have '#{key}' field, got: #{inspect(Map.keys(candidate))}"
          end)
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
