defmodule MarketMySpecSpex.Story683.Criterion5838Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5838 — edit_file does exact-string replacement; requires prior read; errors on
  non-unique old_string unless replace_all is true; errors with not_found on missing path.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{EditFile, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/04_positioning.md"
  @body "# Positioning\nWe are the X for Y.\nWe are the X for Y."

  spex "edit_file enforces exact-string semantics with read-before-edit gating" do
    scenario "non-unique old_string without replace_all is rejected; with replace_all replaces all" do
      given_ "an authenticated user with a read artifact in session", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: @body}, frame)
        {:reply, _, frame} = ReadFile.execute(%{path: @path}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls edit_file with a non-unique old_string and no replace_all", context do
        {:reply, response, frame} =
          EditFile.execute(
            %{path: @path, old_string: "X for Y", new_string: "Z for W"},
            context.frame
          )

        {:ok, Map.merge(context, %{non_unique_response: response, frame: frame})}
      end

      then_ "the edit is rejected with a non-uniqueness error", context do
        assert context.non_unique_response.isError
        {:ok, context}
      end

      when_ "the agent retries with replace_all set", context do
        {:reply, response, frame} =
          EditFile.execute(
            %{path: @path, old_string: "X for Y", new_string: "Z for W", replace_all: true},
            context.frame
          )

        {:ok, Map.merge(context, %{replace_all_response: response, frame: frame})}
      end

      then_ "the edit succeeds and read_file shows both occurrences replaced", context do
        refute context.replace_all_response.isError

        {:reply, read_response, _} = ReadFile.execute(%{path: @path}, context.frame)
        text = response_text(read_response)
        refute text =~ "X for Y"
        assert text =~ "Z for W"

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
