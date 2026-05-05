defmodule MarketMySpecSpex.Story683.Criterion5867Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5867 — delete_file after a read in the same session removes the object.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{DeleteFile, ListFiles, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/to_delete.md"

  spex "delete_file after read removes the object" do
    scenario "agent reads, deletes, then list does not include the path" do
      given_ "an authenticated user with an artifact already read", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: "x"}, frame)
        {:reply, _, frame} = ReadFile.execute(%{path: @path}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls delete_file", context do
        {:reply, response, frame} = DeleteFile.execute(%{path: @path}, context.frame)
        {:ok, Map.merge(context, %{delete_response: response, frame: frame})}
      end

      then_ "delete_file returns success", context do
        refute context.delete_response.isError
        {:ok, context}
      end

      when_ "the agent lists files", context do
        {:reply, response, _} = ListFiles.execute(%{}, context.frame)
        {:ok, Map.put(context, :list_response, response)}
      end

      then_ "the deleted path is not in the listing", context do
        keys = response_keys(context.list_response)
        refute @path in keys
        {:ok, context}
      end
    end
  end

  defp response_keys(%Anubis.Server.Response{content: parts}) when is_list(parts) do
    Enum.flat_map(parts, fn
      %{"text" => t} -> String.split(t, "\n", trim: true)
      _ -> []
    end)
  end

  defp response_keys(%{keys: keys}) when is_list(keys), do: keys
  defp response_keys(other), do: List.wrap(other)
end
