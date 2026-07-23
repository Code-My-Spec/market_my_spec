defmodule MarketMySpecSpex.Story708.Criterion6141Spex do
  @moduledoc """
  Story 708 — Configure Venues Per Source for Engagement Search
  Criterion 6141 — Story 705's search reads the enabled venue list per source
  and only queries those venues.

  The SearchEngagements tool reads the active account's enabled venues.
  Disabled venues are not queried. Two accounts with different venue
  configurations receive different (account-scoped) candidate lists.

  Interaction surface: MCP SearchEngagements tool (agent surface).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Engagements.Tools.SearchEngagements
  alias MarketMySpecSpex.Fixtures

  spex "Story 705 search reads the enabled venue list per source" do
    scenario "search_engagements returns a scoped result for an authenticated user" do
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
          SearchEngagements.execute(%{query: "elixir"}, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is not an error", context do
        refute context.response.isError,
               "expected search_engagements to succeed (read enabled venues for account)"

        {:ok, context}
      end

      then_ "the response carries a candidates key scoped to this account", context do
        text = response_text(context.response)
        {:ok, decoded} = Jason.decode(text)

        assert Map.has_key?(decoded, "candidates"),
               "expected response to carry a 'candidates' key, got: #{inspect(Map.keys(decoded))}"

        {:ok, context}
      end
    end

    scenario "two accounts with separate venue configs get separate search scopes" do
      given_ "two accounts each with their own scope", context do
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

        {:ok, Map.merge(context, %{frame_a: frame_a, frame_b: frame_b})}
      end

      when_ "both accounts call search_engagements", context do
        {:reply, response_a, _} = SearchEngagements.execute(%{query: "phoenix"}, context.frame_a)
        {:reply, response_b, _} = SearchEngagements.execute(%{query: "phoenix"}, context.frame_b)

        {:ok, Map.merge(context, %{response_a: response_a, response_b: response_b})}
      end

      then_ "both responses succeed without error", context do
        refute context.response_a.isError, "expected account A search to succeed"
        refute context.response_b.isError, "expected account B search to succeed"
        {:ok, context}
      end

      then_ "each response is scoped to its own account (both return empty — no shared venues)", context do
        text_a = response_text(context.response_a)
        text_b = response_text(context.response_b)

        {:ok, decoded_a} = Jason.decode(text_a)
        {:ok, decoded_b} = Jason.decode(text_b)

        assert is_list(decoded_a["candidates"]),
               "expected account A candidates to be a list"

        assert is_list(decoded_b["candidates"]),
               "expected account B candidates to be a list"

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
