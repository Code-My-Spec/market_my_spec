defmodule MarketMySpecSpex.Story683.Criterion5866Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5866 — edit_file on a missing path returns not_found.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.EditFile
  alias MarketMySpecSpex.Fixtures

  spex "edit_file on missing path returns not_found" do
    scenario "agent attempts to edit a path that was never written" do
      given_ "an authenticated user with an empty workspace", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls edit_file on a non-existent path", context do
        {:reply, response, _} =
          EditFile.execute(
            %{path: "marketing/never.md", old_string: "x", new_string: "y"},
            context.frame
          )

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is a not_found error", context do
        assert context.response.isError
        text = response_text(context.response)
        assert text =~ ~r/not[_ ]?found/i
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
