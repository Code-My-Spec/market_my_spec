defmodule MarketMySpecSpex.Story683.Criterion5853Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5853 — A relative path passed by the agent resolves under the caller's account
  prefix server-side; the agent never sees or has to manage account scoping.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ListFiles, WriteFile}
  alias MarketMySpecSpex.Fixtures

  spex "relative paths resolve to the caller's account prefix" do
    scenario "agent writes a relative path; list_files returns it relative, no prefix leak" do
      given_ "an authenticated user with active account scope", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent writes a file with a relative path", context do
        {:reply, _, frame} =
          WriteFile.execute(%{path: "marketing/relative.md", content: "x"}, context.frame)

        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent lists files", context do
        {:reply, response, _} = ListFiles.execute(%{}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the listed key is the relative path with no accounts/ prefix", context do
        keys = response_keys(context.response)
        assert "marketing/relative.md" in keys
        refute Enum.any?(keys, &String.contains?(&1, "accounts/"))
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
