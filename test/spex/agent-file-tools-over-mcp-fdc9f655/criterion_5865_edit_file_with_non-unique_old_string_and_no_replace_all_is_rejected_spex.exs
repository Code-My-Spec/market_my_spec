defmodule MarketMySpecSpex.Story683.Criterion5865Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5865 — edit_file with a non-unique old_string and no replace_all is rejected.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{EditFile, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/non_unique.md"
  @body "foo\nfoo\nbar"

  spex "edit_file rejects non-unique old_string without replace_all" do
    scenario "agent reads, then attempts edit with a substring that appears multiple times" do
      given_ "an authenticated user with a read artifact in session", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: @body}, frame)
        {:reply, _, frame} = ReadFile.execute(%{path: @path}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls edit_file with a non-unique old_string and no replace_all", context do
        {:reply, response, _} =
          EditFile.execute(
            %{path: @path, old_string: "foo", new_string: "baz"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is an error indicating non-uniqueness", context do
        assert context.response.isError
        {:ok, context}
      end
    end
  end
end
