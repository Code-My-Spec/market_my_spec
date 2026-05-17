defmodule MarketMySpecSpex.Story716.Criterion6356Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6356 — Posted transition without comment_url is rejected;
  row stays staged.

  Sister to 6335; pinned via Three Amigos scenario.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
  alias MarketMySpec.McpServers.Engagements.Tools.StageResponse
  alias MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint
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

  spex "posted transition without comment_url is rejected; row stays :staged" do
    scenario "Update to :posted with no comment_url returns error; list shows :staged" do
      given_ "a staged Touchpoint", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "rej356"})
        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{thread_id: thread.id, polished_body: "Body", link_target: "https://x"},
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:ok, Map.merge(context, %{frame: frame, thread: thread, touchpoint_id: touchpoint_id})}
      end

      when_ "agent calls update_touchpoint state: :posted with NO comment_url, NO posted_at",
            context do
        {:reply, update_resp, _} =
          UpdateTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, state: "posted"},
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           update_resp: update_resp,
           payload: decode_payload(list_resp)
         })}
      end

      then_ "update returns error; row still :staged with comment_url/posted_at nil", context do
        case context.update_resp do
          %Response{isError: true} -> :ok
          other -> flunk("expected error on partial posted transition, got: #{inspect(other)}")
        end

        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected touchpoint still in list"

        assert (tp["state"] || tp[:state]) in ["staged", :staged],
               "expected state still :staged, got: #{inspect(tp["state"] || tp[:state])}"

        assert (tp["comment_url"] || tp[:comment_url]) == nil
        assert (tp["posted_at"] || tp[:posted_at]) == nil

        {:ok, context}
      end
    end
  end
end
