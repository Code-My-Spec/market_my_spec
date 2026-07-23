defmodule MarketMySpecSpex.Story683.Criterion5861Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5861 — write_file on an existing path without a prior read in the same session is rejected.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.WriteFile
  alias MarketMySpecSpex.Fixtures

  @path "marketing/locked.md"

  spex "write_file rejects overwrite without prior read" do
    scenario "fresh session attempts to overwrite an existing path" do
      given_ "an existing artifact written by a previous session", context do
        scope = Fixtures.account_scoped_user_fixture()

        prior_frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-prior-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, _} = WriteFile.execute(%{path: @path, content: "v1"}, prior_frame)

        new_frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-new-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: new_frame})}
      end

      when_ "a fresh session calls write_file without reading first", context do
        {:reply, response, _} = WriteFile.execute(%{path: @path, content: "v2"}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is an error", context do
        assert context.response.isError
        {:ok, context}
      end
    end
  end
end
