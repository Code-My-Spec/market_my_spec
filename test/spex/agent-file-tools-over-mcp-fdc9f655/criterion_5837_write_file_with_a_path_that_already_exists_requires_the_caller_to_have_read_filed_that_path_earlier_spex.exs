defmodule MarketMySpecSpex.Story683.Criterion5837Spex do
  @moduledoc """
  Story 683 — Agent File Tools Over MCP
  Criterion 5837 — write_file with an existing path requires a prior read_file in the same
  MCP session; without prior read returns a read-required error and does not overwrite.
  With prior read, overwrites in place.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.{ReadFile, WriteFile}
  alias MarketMySpecSpex.Fixtures

  @path "marketing/03_message.md"
  @v1 "# v1\nFirst draft."
  @v2 "# v2\nRefined message."

  spex "write_file gates overwrite on a prior read in the same session" do
    scenario "writing twice without a read between is rejected; reading then writing succeeds" do
      given_ "an authenticated user with an active account scope and an existing artifact", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, _, frame} = WriteFile.execute(%{path: @path, content: @v1}, frame)
        {:ok, Map.merge(context, %{scope: scope, frame: frame})}
      end

      when_ "a fresh session attempts to overwrite without reading first", context do
        fresh_frame = %{
          assigns: context.frame.assigns,
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        {:reply, response, fresh_frame} =
          WriteFile.execute(%{path: @path, content: @v2}, fresh_frame)

        {:ok, Map.merge(context, %{no_read_response: response, fresh_frame: fresh_frame})}
      end

      then_ "the overwrite is rejected with a read-required error", context do
        assert context.no_read_response.isError,
               "Expected error response when overwriting without prior read"

        {:ok, context}
      end

      when_ "the same session reads the path then writes again", context do
        {:reply, _, frame} = ReadFile.execute(%{path: @path}, context.fresh_frame)
        {:reply, response, frame} = WriteFile.execute(%{path: @path, content: @v2}, frame)
        {:ok, Map.merge(context, %{after_read_response: response, frame: frame})}
      end

      then_ "the overwrite succeeds after a prior read", context do
        refute context.after_read_response.isError
        {:ok, context}
      end
    end
  end
end
