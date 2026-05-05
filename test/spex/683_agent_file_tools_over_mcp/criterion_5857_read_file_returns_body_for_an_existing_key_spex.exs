defmodule MarketMySpecSpex.Story683.Criterion5857Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5857 — read_file returns the body for an existing key.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/icp.md"
  @body "ICP body content."

  spex "read_file returns the body for an existing key" do
    scenario "agent reads a file it just wrote" do
      given_ "an authenticated user with an artifact already written", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: @body}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls read_file", context do
        {:reply, response, _} = ReadFile.execute(%{path: @path}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response carries the body that was written", context do
        refute context.response.isError
        text = response_text(context.response)
        assert text == @body
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
