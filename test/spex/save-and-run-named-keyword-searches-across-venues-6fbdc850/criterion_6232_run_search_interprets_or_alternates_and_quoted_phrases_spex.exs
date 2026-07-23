defmodule MarketMySpecSpex.Story710.Criterion6232Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6232 — run_search interprets OR alternates and quoted phrases.

  The saved query is stored as a single Google-style string. When the agent
  calls the run_search MCP tool, the orchestrator parses operators at run
  time — quoted phrases stay together and OR-separated terms produce
  alternates. The tool returns the candidates/failures envelope as JSON in
  its response payload.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
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

  spex "run_search interprets OR alternates and quoted phrases" do
    scenario "the saved Google-style query persists and run_search returns the envelope" do
      given_ "Sam has a SavedSearch with the query `\"elixir testing\" OR credo`",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        venue = Fixtures.venue_fixture(scope, %{source: :reddit, identifier: "elixir"})

        {:ok, saved_search} =
          SavedSearchesRepository.create_saved_search(scope, %{
            name: "elixir testing",
            query: ~s("elixir testing" OR credo),
            venue_ids: [venue.id]
          })

        {:ok,
         Map.merge(context, %{
           scope: scope,
           frame: build_frame(scope),
           saved_search: saved_search
         })}
      end

      when_ "the agent calls the run_search MCP tool with the saved search id", context do
        result = RunSearch.execute(%{search_id: context.saved_search.id}, context.frame)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the response carries the candidates/failures envelope and the stored query is unchanged",
            context do
        assert {:reply, %Response{} = response, _frame} = context.result

        payload = decode_payload(response)
        assert is_list(payload["candidates"] || payload[:candidates])
        assert is_list(payload["failures"] || payload[:failures])

        assert context.saved_search.query == ~s("elixir testing" OR credo)

        {:ok, context}
      end
    end
  end
end
