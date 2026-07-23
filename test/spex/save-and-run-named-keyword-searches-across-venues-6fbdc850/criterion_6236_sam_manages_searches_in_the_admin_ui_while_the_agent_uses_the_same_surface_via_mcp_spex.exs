defmodule MarketMySpecSpex.Story710.Criterion6236Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6236 — Sam manages searches in the admin UI while the agent
  uses the same surface via MCP.

  Both the LiveView admin and the MCP tool surface read the same
  SavedSearch records. The agent calls list_searches via the MCP tool and
  sees exactly what was created on the account — including searches
  created by the admin UI.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpec.McpServers.Engagements.Tools.ListSearches
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    text =
      Enum.map_join(parts, "\n", fn
        %{"text" => t} -> t
        %{text: t} -> t
        other -> inspect(other)
      end)

    Jason.decode!(text)
  end

  spex "the agent's list_searches MCP call returns what the admin UI wrote" do
    scenario "two saved searches created on Sam's account both appear in list_searches" do
      given_ "Sam has two SavedSearches on his account", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, _} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "elixir testing",
            query: "elixir testing",
            venue_ids: [venue.id]
          })

        {:ok, _} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "credo",
            query: "credo",
            venue_ids: [venue.id]
          })

        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope)})}
      end

      when_ "the agent calls the list_searches MCP tool", context do
        {:reply, response, _frame} = ListSearches.execute(%{}, context.frame)
        {:ok, Map.put(context, :payload, decode_payload(response))}
      end

      then_ "both saved searches appear in the response payload", context do
        searches = context.payload["searches"] || context.payload[:searches]
        assert is_list(searches), "expected a searches list in the response payload"

        names = searches |> Enum.map(&(&1["name"] || &1[:name])) |> Enum.sort()
        assert names == ["credo", "elixir testing"]

        {:ok, context}
      end
    end
  end
end
