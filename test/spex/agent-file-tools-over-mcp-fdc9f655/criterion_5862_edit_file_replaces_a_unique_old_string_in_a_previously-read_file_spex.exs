defmodule MarketMySpecSpex.Story683.Criterion5862Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5862 — edit_file replaces a unique old_string in a previously-read file.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{EditFile, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/edit_unique.md"
  @body "Hello world. This is a test."

  spex "edit_file replaces a unique substring after a prior read" do
    scenario "agent reads, edits with unique old_string, and the change sticks" do
      given_ "an authenticated user with an existing artifact and a read on it", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: @body}, frame)
        {:reply, _, frame} = ReadFile.execute(%{path: @path}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls edit_file with a unique old_string", context do
        {:reply, response, frame} =
          EditFile.execute(
            %{path: @path, old_string: "Hello world", new_string: "Hi planet"},
            context.frame
          )

        {:ok, Map.merge(context, %{edit_response: response, frame: frame})}
      end

      then_ "edit_file returns success", context do
        refute context.edit_response.isError
        {:ok, context}
      end

      when_ "the agent reads the file again", context do
        {:reply, response, _} = ReadFile.execute(%{path: @path}, context.frame)
        {:ok, Map.put(context, :read_response, response)}
      end

      then_ "the file contains the new substring and not the old", context do
        text = response_text(context.read_response)
        refute text =~ "Hello world"
        assert text =~ "Hi planet"
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
