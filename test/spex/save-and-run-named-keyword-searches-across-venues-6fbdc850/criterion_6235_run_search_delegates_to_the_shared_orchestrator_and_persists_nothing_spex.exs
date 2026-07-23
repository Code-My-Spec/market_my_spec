defmodule MarketMySpecSpex.Story710.Criterion6235Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6235 — run_search delegates to the shared orchestrator and
  persists nothing.

  The run_search MCP tool returns the same `%{candidates, failures}` envelope
  as the ad-hoc search_engagements tool, and persists no run-history rows.
  We assert the envelope shape on the MCP response and that the SavedSearch
  schema has no run-history fields.

  Interaction surface: MCP tool execution (agent surface) +
  SavedSearch schema introspection.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements.SavedSearch
  alias MarketMySpec.Engagements.SavedSearchesRepository
  alias MarketMySpec.McpServers.Engagements.Tools.RunSearch
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

  spex "run_search delegates to the shared orchestrator and persists nothing" do
    scenario "the MCP envelope matches ad-hoc search and the schema has no run-history fields" do
      given_ "Sam has a SavedSearch", context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, saved_search} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "elixir hiring",
            query: "elixir hiring",
            venue_ids: [venue.id]
          })

        {:ok,
         Map.merge(context, %{
           scope: scope,
           frame: build_frame(scope),
           saved_search: saved_search
         })}
      end

      when_ "the agent calls the run_search MCP tool", context do
        result = RunSearch.execute(%{search_id: context.saved_search.id}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the envelope shape matches and the schema has no run-history fields", context do
        assert {:reply, %Response{} = response, _frame} = context.result

        payload = decode_payload(response)
        assert is_list(payload["candidates"] || payload[:candidates])
        assert is_list(payload["failures"] || payload[:failures])

        # Recipe-only: no `last_run_at` / `run_count` on the schema.
        fields = SavedSearch.__schema__(:fields)
        refute :last_run_at in fields
        refute :run_count in fields

        {:ok, context}
      end
    end
  end
end
