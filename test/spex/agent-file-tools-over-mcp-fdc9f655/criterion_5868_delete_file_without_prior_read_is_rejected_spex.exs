defmodule MarketMySpecSpex.Story683.Criterion5868Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5868 — delete_file without a prior read in the same session is rejected.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{DeleteFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/protected.md"

  spex "delete_file rejects deletion without prior read" do
    scenario "fresh session attempts to delete an existing file without reading first" do
      given_ "an existing artifact written by a prior session", context do
        scope = Fixtures.account_scoped_user_fixture()

        prior_frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-prior-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, _} = WriteFile.execute(%{path: @path, content: "x"}, prior_frame)

        new_frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-new-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: new_frame})}
      end

      when_ "the fresh session calls delete_file without reading first", context do
        {:reply, response, _} = DeleteFile.execute(%{path: @path}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is an error", context do
        assert context.response.isError
        {:ok, context}
      end
    end
  end
end
