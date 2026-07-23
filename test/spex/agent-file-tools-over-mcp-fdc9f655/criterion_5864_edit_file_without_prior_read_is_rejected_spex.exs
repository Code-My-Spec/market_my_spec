defmodule MarketMySpecSpex.Story683.Criterion5864Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5864 — edit_file without a prior read in the same session is rejected.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{EditFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/needs_read.md"

  spex "edit_file rejects edits without a prior read" do
    scenario "fresh session attempts to edit an existing file without reading first" do
      given_ "an existing artifact and a fresh session", context do
        scope = Fixtures.account_scoped_user_fixture()

        prior_frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-prior-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, _} = WriteFile.execute(%{path: @path, content: "old"}, prior_frame)

        new_frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-new-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: new_frame})}
      end

      when_ "the fresh session calls edit_file without reading first", context do
        {:reply, response, _} =
          EditFile.execute(
            %{path: @path, old_string: "old", new_string: "new"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is an error", context do
        assert context.response.isError
        {:ok, context}
      end
    end
  end
end
