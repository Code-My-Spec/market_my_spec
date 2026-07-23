defmodule MarketMySpecSpex.Story683.Criterion5854Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5854 — Path traversal (..) is rejected on every file tool.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{DeleteFile, EditFile, ListFiles, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  spex "every file tool rejects .. in the path" do
    scenario "read/write/edit/delete/list with traversal paths all return errors" do
      given_ "an authenticated user with active account scope", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "every tool is called with a traversal path", context do
        {:reply, r1, _} = ReadFile.execute(%{path: "../neighbor/secret.md"}, context.frame)
        {:reply, r2, _} = WriteFile.execute(%{path: "../neighbor/x", content: "y"}, context.frame)

        {:reply, r3, _} =
          EditFile.execute(
            %{path: "../neighbor/x", old_string: "y", new_string: "z"},
            context.frame
          )

        {:reply, r4, _} = DeleteFile.execute(%{path: "../neighbor/x"}, context.frame)
        {:reply, r5, _} = ListFiles.execute(%{prefix: "../neighbor/"}, context.frame)
        {:ok, Map.put(context, :responses, [r1, r2, r3, r4, r5])}
      end

      then_ "every response is an error", context do
        for %Anubis.Server.Response{} = r <- context.responses do
          assert r.isError, "Expected error for traversal, got: #{inspect(r)}"
        end

        {:ok, context}
      end
    end
  end
end
