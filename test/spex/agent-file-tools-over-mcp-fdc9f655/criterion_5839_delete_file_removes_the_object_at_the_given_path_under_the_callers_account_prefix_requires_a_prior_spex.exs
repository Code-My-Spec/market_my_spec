defmodule MarketMySpecSpex.Story683.Criterion5839Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5839 — delete_file removes the object at the path; requires a prior read in the
  same session; subsequent read_file returns not_found.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{DeleteFile, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/05_channels.md"
  @body "# Channels\nReddit, Discord, ElixirForum."

  spex "delete_file removes a file after a read in the session" do
    scenario "agent reads, deletes, then reading the same path returns not_found" do
      given_ "an authenticated user with an existing artifact read in session", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: @body}, frame)
        {:reply, _, frame} = ReadFile.execute(%{path: @path}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls delete_file on the path", context do
        {:reply, response, frame} = DeleteFile.execute(%{path: @path}, context.frame)
        {:ok, Map.merge(context, %{delete_response: response, frame: frame})}
      end

      then_ "delete_file returns success", context do
        refute context.delete_response.isError
        {:ok, context}
      end

      when_ "the agent calls read_file on the same path", context do
        {:reply, response, _} = ReadFile.execute(%{path: @path}, context.frame)
        {:ok, Map.put(context, :read_response, response)}
      end

      then_ "read_file returns a not_found error", context do
        assert context.read_response.isError
        {:ok, context}
      end
    end
  end
end
