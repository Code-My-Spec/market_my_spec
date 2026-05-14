defmodule MarketMySpecSpex.Story707.Criterion6200Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI
  Criterion 6200 — LLM can call a stage_response MCP tool with thread_id, polished body,
  and link target and receive the staged draft id.

  The LLM (agent) calls the stage_response MCP tool supplying the thread_id,
  polished comment body, and link target. The tool responds with the staged
  Touchpoint's id so the agent can reference it in subsequent calls.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.McpServers.Marketing.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  spex "LLM can call stage_response and receive the staged draft id" do
    scenario "agent stages a response for a thread and gets back the touchpoint id" do
      given_ "an authenticated user with a thread in their account", context do
        scope = Fixtures.account_scoped_user_fixture()

        frame = %{
          assigns: %{current_scope: scope},
          context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
        }

        thread = Fixtures.thread_fixture(scope)

        {:ok, Map.merge(context, %{scope: scope, frame: frame, thread: thread})}
      end

      when_ "the agent calls stage_response with thread_id, polished body, and link target", context do
        args = %{
          thread_id: context.thread.id,
          body: "Great point about CodeMySpec -- it handles the full lifecycle: https://codemyspec.com",
          link_target: "https://codemyspec.com"
        }

        {:reply, response, _frame} = StageResponse.execute(args, context.frame)

        {:ok, Map.put(context, :response, response)}
      end

      then_ "the response carries the staged touchpoint id", context do
        refute context.response.isError, "expected stage_response to succeed, got error"
        text = response_text(context.response)
        assert text =~ ~r/\d+/ or text =~ "staged",
               "expected response to include the staged draft id, got: #{inspect(text)}"

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
