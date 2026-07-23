defmodule MarketMySpecSpex.Story683.Criterion5841Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5841 — Every tool resolves the path under accounts/{account_id}/ using the bearer
  token's resolved account; path traversal (..) and absolute paths are rejected; no addressable
  way for the agent to reach another account's keys.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  spex "every file tool scopes to the caller's account and rejects unsafe paths" do
    scenario "absolute and traversal paths are rejected on read and write" do
      given_ "an authenticated user with active account scope", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls write_file with an absolute path", context do
        {:reply, response, _} =
          WriteFile.execute(%{path: "/etc/passwd", content: "x"}, context.frame)

        {:ok, Map.put(context, :abs_response, response)}
      end

      then_ "the absolute path is rejected", context do
        assert context.abs_response.isError
        {:ok, context}
      end

      when_ "the agent calls read_file with a traversal path", context do
        {:reply, response, _} =
          ReadFile.execute(%{path: "../other-account/secret.md"}, context.frame)

        {:ok, Map.put(context, :traverse_response, response)}
      end

      then_ "the traversal path is rejected", context do
        assert context.traverse_response.isError
        {:ok, context}
      end
    end
  end
end
