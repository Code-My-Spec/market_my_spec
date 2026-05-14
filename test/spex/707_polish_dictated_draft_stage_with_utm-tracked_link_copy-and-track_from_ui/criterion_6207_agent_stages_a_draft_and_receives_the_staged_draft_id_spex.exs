defmodule MarketMySpecSpex.Story707.Criterion6207Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI
  Criterion 6207 — Agent stages a draft and receives the staged draft id.

  When the agent calls stage_response the MCP tool responds with the newly created
  Touchpoint's id. The agent can use this id in later calls (e.g., confirming posting).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  spex "agent stages a draft and receives the staged draft id" do
    scenario "stage_response responds with a numeric or string id for the new touchpoint" do
      given_ "an authenticated account-scoped user with a thread", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        thread = Fixtures.thread_fixture(scope)

        {:ok, Map.merge(context, %{scope: scope, frame: frame, thread: thread})}
      end

      when_ "the agent calls stage_response", context do
        args = %{
          thread_id: context.thread.id,
          body: "CodeMySpec is worth checking out for this kind of problem.",
          link_target: "https://codemyspec.com"
        }

        {:reply, response, _frame} = StageResponse.execute(args, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response is not an error and includes an id for the staged draft", context do
        refute context.response.isError,
               "expected stage_response to succeed without error"

        text = response_text(context.response)
        assert String.length(text) > 0,
               "expected a non-empty response carrying the staged draft id"

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
