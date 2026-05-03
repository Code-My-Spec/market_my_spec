defmodule MarketMySpecSpex.Story676.Criterion5849Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Account
  Criterion 5849 — User completes step 5 and finds positioning.md in their account workspace
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ListFiles, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @positioning_path "marketing/05_positioning.md"

  @positioning_body """
  # Positioning — Acme Granite

  ## 1. Competitive alternatives
  - Do nothing: keep formica counters
  - DIY: laminate
  - Direct: regional fabricators with 3-week lead times

  ## 2. Unique attributes
  In-house CNC fabrication, same-day design changes, 5-day install vs. industry 21.
  """

  spex "the agent persists step 5 to the account workspace via write_file" do
    scenario "agent writes step 5 → read_file returns the body → list_files includes the key" do
      given_ "an authenticated user with an active account scope", context do
        # Future fixture: builds a confirmed user, an account, a Member row, and
        # a Scope with active_account_id set. Ships when the Accounts fixtures land.
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.put(context, :scope, scope)}
      end

      given_ "an MCP session frame carrying the scope and a stable session id", context do
        # Anubis exposes frame.context.session_id per MCP session; tests synthesize an
        # equivalent shape — when anubis_mcp is added to deps, swap to %Anubis.Server.Frame{}.
        frame = %{
          assigns: %{current_scope: context.scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent finishes step 5 and calls write_file with the canonical positioning path", context do
        {:reply, response, frame} =
          WriteFile.execute(
            %{path: @positioning_path, content: @positioning_body},
            context.frame
          )

        {:ok, Map.merge(context, %{write_response: response, frame: frame})}
      end

      then_ "write_file returns success", context do
        # Anubis success responses are non-error tool responses; we assert the response
        # carries a non-error indicator. Final shape lands when the tool module is implemented.
        refute Map.get(context.write_response, :is_error, false),
               "Expected write_file to succeed, got: #{inspect(context.write_response)}"

        {:ok, context}
      end

      when_ "a read_file under the same scope is issued for the same path", context do
        {:reply, response, frame} =
          ReadFile.execute(%{path: @positioning_path}, context.frame)

        {:ok, Map.merge(context, %{read_response: response, frame: frame})}
      end

      then_ "read_file returns the byte-exact body that was written", context do
        text = response_text(context.read_response)

        assert text == @positioning_body,
               "Expected read_file to return the exact body that write_file persisted"

        {:ok, context}
      end

      when_ "list_files is called with the marketing/ prefix under the same scope", context do
        {:reply, response, _frame} =
          ListFiles.execute(%{prefix: "marketing/"}, context.frame)

        {:ok, Map.put(context, :list_response, response)}
      end

      then_ "list_files includes marketing/05_positioning.md as a relative key", context do
        keys = response_keys(context.list_response)

        assert @positioning_path in keys,
               "Expected #{@positioning_path} in list_files response, got: #{inspect(keys)}"

        refute Enum.any?(keys, &String.starts_with?(&1, "accounts/")),
               "list_files leaked the accounts/ prefix in returned keys: #{inspect(keys)}"

        {:ok, context}
      end
    end
  end

  defp response_text(%{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "\n", fn
      %{text: t} -> t
      %{"text" => t} -> t
      other -> inspect(other)
    end)
  end

  defp response_text(%{text: text}), do: text
  defp response_text(other), do: inspect(other)

  defp response_keys(%{content: parts}) when is_list(parts) do
    Enum.flat_map(parts, fn
      %{text: t} -> String.split(t, "\n", trim: true)
      %{"text" => t} -> String.split(t, "\n", trim: true)
      _ -> []
    end)
  end

  defp response_keys(%{keys: keys}) when is_list(keys), do: keys
  defp response_keys(other), do: List.wrap(other)
end
