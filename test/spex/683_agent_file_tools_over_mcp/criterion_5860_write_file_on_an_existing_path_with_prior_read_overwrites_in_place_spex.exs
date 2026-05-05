defmodule MarketMySpecSpex.Story683.Criterion5860Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5860 — write_file on an existing path with a prior read overwrites in place.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/overwrite.md"

  spex "write_file overwrites in place after a prior read in the same session" do
    scenario "agent reads, then writes, and the new body sticks" do
      given_ "an authenticated user with an existing artifact and a read on it", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: "v1"}, frame)
        {:reply, _, frame} = ReadFile.execute(%{path: @path}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls write_file with a new body", context do
        {:reply, response, frame} = WriteFile.execute(%{path: @path, content: "v2"}, context.frame)
        {:ok, Map.merge(context, %{response: response, frame: frame})}
      end

      then_ "write_file returns success", context do
        refute context.response.isError
        {:ok, context}
      end

      when_ "the agent reads the path again", context do
        {:reply, response, _} = ReadFile.execute(%{path: @path}, context.frame)
        {:ok, Map.put(context, :read_response, response)}
      end

      then_ "the body is the new value", context do
        text = response_text(context.read_response)
        assert text == "v2"
        {:ok, context}
      end
    end
  end

  defp response_text(%Anubis.Server.Response{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(other), do: inspect(other)
end
