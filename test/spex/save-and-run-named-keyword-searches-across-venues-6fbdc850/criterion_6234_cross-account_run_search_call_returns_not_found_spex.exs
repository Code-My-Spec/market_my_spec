defmodule MarketMySpecSpex.Story710.Criterion6234Spex do
  @moduledoc """
  Story 710 — Save and Run Named Keyword Searches Across Venues
  Criterion 6234 — Cross-account run_search call returns not_found.

  Account A owns SavedSearch S. Dave's frame is scoped to Account B (no
  membership in A). When Dave's agent calls the run_search MCP tool with S's
  id, the tool returns an error response — no candidate data leaks.

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

  spex "Cross-account run_search call returns not_found" do
    scenario "Account B's frame cannot run Account A's saved search" do
      given_ "Account A owns SavedSearch S, Dave's frame is scoped to Account B", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        venue_a = Fixtures.venue_fixture(scope_a, %{source: :reddit, identifier: "elixir"})

        {:ok, saved_search} =
          SavedSearchesRepository.create_saved_search(scope_a, %{
            name: "a only",
            query: "elixir",
            venue_ids: [venue_a.id]
          })

        {:ok,
         Map.merge(context, %{
           frame_b: build_frame(scope_b),
           saved_search: saved_search
         })}
      end

      when_ "Dave's frame calls run_search with A's search id", context do
        result = RunSearch.execute(%{search_id: context.saved_search.id}, context.frame_b)
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the tool returns an error response and no candidate data is leaked", context do
        assert {:reply, %Response{} = response, _frame} = context.result
        assert response.isError, "expected isError=true on cross-account run_search"

        # Even when erroring, the response must not contain candidate data
        # belonging to account A. Stringify the whole content list and assert
        # no telltale leak markers — a coarse check that's still useful.
        text = inspect(response.content)
        refute text =~ "candidates"

        {:ok, context}
      end
    end
  end
end
