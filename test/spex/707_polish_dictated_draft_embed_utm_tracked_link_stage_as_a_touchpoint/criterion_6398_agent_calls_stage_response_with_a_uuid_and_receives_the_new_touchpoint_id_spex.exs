defmodule MarketMySpecSpex.Story707.Criterion6398Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6398 — Agent calls `stage_response(thread_id: UUID,
  polished_body, link_target)` with a UUID from a prior search and
  receives the new Touchpoint id.

  Happy-path entry point: thread_id is the UUID Story 705 returned
  (Threads are persisted up-front). stage_response returns a payload
  containing the newly-created Touchpoint id (UUID).

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpecSpex.Fixtures

  defp build_frame(scope) do
    %{
      assigns: %{current_scope: scope},
      context: %{session_id: "spec-#{System.unique_integer([:positive])}"}
    }
  end

  defp decode_payload(%Response{content: parts}) when is_list(parts) do
    parts
    |> Enum.map_join("\n", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
    |> Jason.decode!()
  end

  defp uuid?(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp uuid?(_), do: false

  spex "stage_response with a thread UUID returns the new Touchpoint id" do
    scenario "Thread UUID from prior search → stage_response → returns Touchpoint id" do
      given_ "a persisted Thread (from a prior search_engagements call)", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "hp398"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent calls stage_response with thread_id, polished_body, link_target", context do
        {:reply, resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Polished body referencing https://marketmyspec.com/x",
              link_target: "https://marketmyspec.com/x"
            },
            context.frame
          )

        payload = decode_payload(resp)
        touchpoint_id = payload["touchpoint_id"] || payload["id"]

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           payload: payload,
           touchpoint_id: touchpoint_id,
           list_payload: decode_payload(list_resp)
         })}
      end

      then_ "the payload carries a UUID Touchpoint id and the row is visible in list_touchpoints",
            context do
        assert uuid?(context.touchpoint_id),
               "expected payload to carry a UUID Touchpoint id, got: #{inspect(context.touchpoint_id)}"

        touchpoints = context.list_payload["touchpoints"] || context.list_payload["list"] || []
        ids = Enum.map(touchpoints, &(&1["id"] || &1[:id]))

        assert context.touchpoint_id in ids,
               "expected returned id present in list_touchpoints; got ids: #{inspect(ids)}"

        {:ok, context}
      end
    end
  end
end
