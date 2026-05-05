defmodule MarketMySpecSpex.Story683.Criterion5835Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5835 — read_file returns body for existing key, not_found for missing,
  never reveals keys outside the caller's account.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/01_icp.md"
  @body "# ICP\n\nSolo founders building AI-native products."

  spex "read_file returns the body for an existing key under the caller's account" do
    scenario "agent writes a file then reads it back" do
      given_ "an authenticated user with an active account scope", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.put(context, :scope, scope)}
      end

      given_ "an MCP frame carrying the scope", context do
        frame = %{
          assigns: %{current_scope: context.scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.put(context, :frame, frame)}
      end

      given_ "the agent has written a file", context do
        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: @body}, context.frame)
        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent calls read_file for the same path", context do
        {:reply, response, frame} = ReadFile.execute(%{path: @path}, context.frame)
        {:ok, Map.merge(context, %{response: response, frame: frame})}
      end

      then_ "read_file returns the body that was written", context do
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
