defmodule MarketMySpecSpex.Story683.Criterion5859Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5859 — write_file on a fresh path creates the object.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ListFiles, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/fresh.md"

  spex "write_file creates a new object on a fresh path" do
    scenario "agent writes to a never-used path" do
      given_ "an authenticated user with an empty workspace", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls write_file on a fresh path", context do
        {:reply, response, frame} =
          WriteFile.execute(%{path: @path, content: "hello"}, context.frame)

        {:ok, Map.merge(context, %{response: response, frame: frame})}
      end

      then_ "write_file returns success", context do
        refute context.response.isError
        {:ok, context}
      end

      when_ "the agent lists files", context do
        {:reply, response, _} = ListFiles.execute(%{}, context.frame)
        {:ok, Map.put(context, :list_response, response)}
      end

      then_ "the new path appears in the listing", context do
        keys = response_keys(context.list_response)
        assert @path in keys
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
