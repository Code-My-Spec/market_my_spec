defmodule MarketMySpecSpex.Story683.Criterion5863Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5863 — edit_file with replace_all replaces every occurrence.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{EditFile, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/replace_all.md"
  @body "TODO\nfix this\nTODO\nand this\nTODO"

  spex "edit_file with replace_all replaces every occurrence" do
    scenario "agent rewrites every TODO" do
      given_ "an authenticated user with an artifact containing repeated tokens", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: @body}, frame)
        {:reply, _, frame} = ReadFile.execute(%{path: @path}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls edit_file with replace_all=true", context do
        {:reply, response, frame} =
          EditFile.execute(
            %{path: @path, old_string: "TODO", new_string: "DONE", replace_all: true},
            context.frame
          )

        {:ok, Map.merge(context, %{edit_response: response, frame: frame})}
      end

      then_ "edit_file returns success", context do
        refute context.edit_response.isError
        {:ok, context}
      end

      when_ "the agent reads the file", context do
        {:reply, response, _} = ReadFile.execute(%{path: @path}, context.frame)
        {:ok, Map.put(context, :read_response, response)}
      end

      then_ "every TODO is replaced with DONE", context do
        text = response_text(context.read_response)
        refute text =~ "TODO"
        assert (text |> String.split("DONE", trim: true) |> length()) >= 2
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
