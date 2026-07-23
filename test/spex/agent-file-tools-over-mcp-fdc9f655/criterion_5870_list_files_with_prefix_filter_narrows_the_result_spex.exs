defmodule MarketMySpecSpex.Story683.Criterion5870Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5870 — list_files with a prefix filter narrows the result.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ListFiles, WriteFile}
  alias MarketMySpecSpex.Fixtures

  spex "list_files with a prefix narrows the result" do
    scenario "agent writes files in two folders; list_files with a prefix returns only one folder" do
      given_ "an authenticated user with files in two folders", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: "marketing/a.md", content: "a"}, frame)
        {:reply, _, frame} = WriteFile.execute(%{path: "marketing/b.md", content: "b"}, frame)
        {:reply, _, frame} = WriteFile.execute(%{path: "research/c.md", content: "c"}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls list_files with prefix marketing/", context do
        {:reply, response, _} = ListFiles.execute(%{prefix: "marketing/"}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "only the marketing files appear", context do
        keys = response_keys(context.response)
        assert "marketing/a.md" in keys
        assert "marketing/b.md" in keys
        refute "research/c.md" in keys
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
