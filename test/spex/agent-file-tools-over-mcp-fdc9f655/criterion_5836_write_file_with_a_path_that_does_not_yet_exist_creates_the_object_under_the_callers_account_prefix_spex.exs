defmodule MarketMySpecSpex.Story683.Criterion5836Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5836 — write_file with a non-existent path creates the object under the caller's
  account prefix; same path becomes readable in the same session.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/02_competitors.md"
  @body "# Competitors\n\nDirect: Cursor, Aider. Indirect: human consultants."

  spex "write_file creates a fresh object readable in the same session" do
    scenario "agent writes to a never-seen path then reads back" do
      given_ "an authenticated user with an active account scope", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls write_file on a fresh path", context do
        {:reply, response, frame} = WriteFile.execute(%{path: @path, content: @body}, context.frame)
        {:ok, Map.merge(context, %{write_response: response, frame: frame})}
      end

      then_ "write_file returns success", context do
        refute context.write_response.isError
        {:ok, context}
      end

      when_ "the agent calls read_file on the same path in the same session", context do
        {:reply, response, frame} = ReadFile.execute(%{path: @path}, context.frame)
        {:ok, Map.merge(context, %{read_response: response, frame: frame})}
      end

      then_ "read_file returns the same body that was written", context do
        refute context.read_response.isError
        text = response_text(context.read_response)
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
