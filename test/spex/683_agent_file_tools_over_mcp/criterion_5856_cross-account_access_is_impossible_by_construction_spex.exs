defmodule MarketMySpecSpex.Story683.Criterion5856Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5856 — Cross-account access is impossible by construction. The bearer token
  resolves to one account, and there is no addressable way for the agent to reach another
  account's keys.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ListFiles, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  spex "no agent-supplied path can reach another account's keys" do
    scenario "Account A writes a file; Account B's agent cannot read or list it" do
      given_ "two distinct account-scoped users", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()

        frame_a = %{
          assigns: %{current_scope: scope_a},
          context: %{session_id: "spec-a-#{System.unique_integer([:positive])}"}
        }

        frame_b = %{
          assigns: %{current_scope: scope_b},
          context: %{session_id: "spec-b-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.merge(context, %{frame_a: frame_a, frame_b: frame_b})}
      end

      when_ "account A writes a file with a relative path", context do
        {:reply, _, frame_a} =
          WriteFile.execute(
            %{path: "marketing/private.md", content: "secret"},
            context.frame_a
          )

        {:ok, Map.put(context, :frame_a, frame_a)}
      end

      when_ "account B attempts to read the same relative path", context do
        {:reply, response, _} =
          ReadFile.execute(%{path: "marketing/private.md"}, context.frame_b)

        {:ok, Map.put(context, :read_response, response)}
      end

      then_ "the read returns not_found (account B has no such key)", context do
        assert context.read_response.isError
        {:ok, context}
      end

      when_ "account B lists files", context do
        {:reply, response, _} = ListFiles.execute(%{}, context.frame_b)
        {:ok, Map.put(context, :list_response, response)}
      end

      then_ "the listing does not include account A's key", context do
        keys = response_keys(context.list_response)
        refute "marketing/private.md" in keys
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
