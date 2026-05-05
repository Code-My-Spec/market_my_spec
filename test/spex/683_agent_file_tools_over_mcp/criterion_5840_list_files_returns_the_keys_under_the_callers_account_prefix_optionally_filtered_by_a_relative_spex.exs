defmodule MarketMySpecSpex.Story683.Criterion5840Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5840 — list_files returns relative keys under the caller's account prefix;
  optionally filtered by a relative prefix; account-prefix never leaks into returned keys.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ListFiles, WriteFile}
  alias MarketMySpecSpex.Fixtures

  spex "list_files returns relative keys under the caller's account" do
    scenario "two files written, list shows both as relative keys with no accounts/ prefix" do
      given_ "an authenticated user with two artifacts written", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: "marketing/a.md", content: "A"}, frame)
        {:reply, _, frame} = WriteFile.execute(%{path: "marketing/b.md", content: "B"}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls list_files with no prefix", context do
        {:reply, response, _} = ListFiles.execute(%{}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response includes both relative keys without the accounts/ prefix", context do
        keys = response_keys(context.response)
        assert "marketing/a.md" in keys
        assert "marketing/b.md" in keys
        refute Enum.any?(keys, &String.starts_with?(&1, "accounts/"))
        {:ok, context}
      end
    end
  end

  defp response_keys(%{content: parts}) when is_list(parts) do
    Enum.flat_map(parts, fn
      %{text: t} -> String.split(t, "\n", trim: true)
      %{"text" => t} -> String.split(t, "\n", trim: true)
      _ -> []
    end)
  end

  defp response_keys(%{keys: keys}) when is_list(keys), do: keys
  defp response_keys(other), do: List.wrap(other)
end
