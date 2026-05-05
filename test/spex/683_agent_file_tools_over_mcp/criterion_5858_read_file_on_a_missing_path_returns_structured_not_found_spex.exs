defmodule MarketMySpecSpex.Story683.Criterion5858Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5858 — read_file on a missing path returns a structured not_found error.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.ReadFile
  alias MarketMySpecSpex.Fixtures

  spex "read_file on a missing path returns not_found" do
    scenario "agent reads a path that was never written" do
      given_ "an authenticated user with an empty workspace", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "the agent calls read_file on a non-existent path", context do
        {:reply, response, _} = ReadFile.execute(%{path: "marketing/missing.md"}, context.frame)
        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is an error indicating not_found", context do
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
