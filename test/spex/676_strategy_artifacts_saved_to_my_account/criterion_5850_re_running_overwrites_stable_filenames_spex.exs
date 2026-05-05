defmodule MarketMySpecSpex.Story676.Criterion5850Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Account
  Criterion 5850 — Re-running the interview overwrites stable filenames, not numbered duplicates
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ListFiles, ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @positioning_path "marketing/05_positioning.md"

  @positioning_v1 """
  # Positioning v1
  Initial draft.
  """

  @positioning_v2 """
  # Positioning v2
  Refined after first run.
  """

  spex "re-running the interview overwrites the canonical filename in place" do
    scenario "v1 → read → v2 leaves a single positioning.md key with the v2 body" do
      given_ "an authenticated user with an active account scope", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.put(context, :scope, scope)}
      end

      given_ "an MCP session frame carrying the scope and a stable session id", context do
        frame = %{
          assigns: %{current_scope: context.scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the first interview run writes positioning v1", context do
        {:reply, _response, frame} =
          WriteFile.execute(
            %{path: @positioning_path, content: @positioning_v1},
            context.frame
          )

        {:ok, Map.put(context, :frame, frame)}
      end

      when_ "the agent reads the existing artifact (read-before-overwrite gate)", context do
        {:reply, response, frame} =
          ReadFile.execute(%{path: @positioning_path}, context.frame)

        {:ok, Map.merge(context, %{read_response: response, frame: frame})}
      end

      then_ "read_file returns the v1 body", context do
        text = response_text(context.read_response)

        assert text == @positioning_v1,
               "Expected v1 body before overwrite, got: #{inspect(text)}"

        {:ok, context}
      end

      when_ "the agent calls write_file with the same path and the v2 body", context do
        {:reply, response, frame} =
          WriteFile.execute(
            %{path: @positioning_path, content: @positioning_v2},
            context.frame
          )

        {:ok, Map.merge(context, %{overwrite_response: response, frame: frame})}
      end

      then_ "the overwrite write_file call succeeds", context do
        refute context.overwrite_response.isError,
               "Expected write_file overwrite to succeed after a prior read_file in the same session"

        {:ok, context}
      end

      when_ "the agent reads the artifact again", context do
        {:reply, response, frame} =
          ReadFile.execute(%{path: @positioning_path}, context.frame)

        {:ok, Map.merge(context, %{post_read_response: response, frame: frame})}
      end

      then_ "the body is now v2 — overwritten in place", context do
        text = response_text(context.post_read_response)

        assert text == @positioning_v2,
               "Expected v2 body after overwrite, got: #{inspect(text)}"

        {:ok, context}
      end

      when_ "the agent lists files under the marketing/ prefix", context do
        {:reply, response, _frame} =
          ListFiles.execute(%{prefix: "marketing/"}, context.frame)

        {:ok, Map.put(context, :list_response, response)}
      end

      then_ "exactly one positioning artifact exists — no numbered or timestamped duplicate", context do
        keys = response_keys(context.list_response)

        positioning_keys =
          Enum.filter(keys, &(&1 =~ ~r/marketing\/05_positioning(_v\d+|_\d+|_\d{8}|_\d{4}-\d{2}-\d{2})?\.md$/))

        assert positioning_keys == [@positioning_path],
               "Expected exactly [\"#{@positioning_path}\"] under marketing/, got: #{inspect(positioning_keys)}"

        refute Enum.any?(keys, &(&1 =~ "_v2.md")),
               "Found a _v2-suffixed positioning file in the listing — re-runs must overwrite, not version: #{inspect(keys)}"

        refute Enum.any?(keys, &(&1 =~ ~r/05_positioning_\d+\.md/)),
               "Found a numbered duplicate positioning file in the listing: #{inspect(keys)}"

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

  defp response_keys(%Anubis.Server.Response{content: parts}) when is_list(parts) do
    Enum.flat_map(parts, fn
      %{"text" => t} -> String.split(t, "\n", trim: true)
      _ -> []
    end)
  end

  defp response_keys(%{keys: keys}) when is_list(keys), do: keys
  defp response_keys(other), do: List.wrap(other)
end
