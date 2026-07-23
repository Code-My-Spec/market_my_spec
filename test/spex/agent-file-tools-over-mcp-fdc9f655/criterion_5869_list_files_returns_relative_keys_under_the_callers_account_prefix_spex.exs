defmodule MarketMySpecSpex.Story683.Criterion5869Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5869 — list_files returns relative keys under the caller's account prefix.
  The accounts/{id}/ prefix never leaks to the agent.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ListFiles, WriteFile}
  alias MarketMySpecSpex.Fixtures

  spex "list_files returns relative keys with no accounts/ prefix" do
    scenario "agent writes, lists, and the keys are stripped of the server-side prefix" do
      given_ "an authenticated user with two artifacts written", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: "marketing/x.md", content: "x"}, frame)
        {:reply, _, frame} = WriteFile.execute(%{path: "marketing/y.md", content: "y"}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent lists files", context do
        {:reply, response, _} = ListFiles.execute(%{}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the listing returns the two relative paths and never leaks the accounts/ prefix", context do
        keys = response_keys(context.response)
        assert "marketing/x.md" in keys
        assert "marketing/y.md" in keys
        refute Enum.any?(keys, &String.starts_with?(&1, "accounts/"))
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
