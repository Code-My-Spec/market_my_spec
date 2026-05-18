defmodule MarketMySpecSpex.Story707.Criterion6470Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as a Touchpoint
  Criterion 6470 — stage_response.polished_body is optional.

  Agent may stage a touchpoint without a body — e.g. immediately after the
  synopsis + angle are formed, before Sam has dictated his rough draft.
  The touchpoint is created with polished_body = nil; body fills in later
  via update_touchpoint or the LiveView edit form.

  Two checks in one scenario:
    1. stage_response with no :polished_body returns a touchpoint_id and the
       row has polished_body = nil and state = :staged.
    2. A later update_touchpoint call can fill the body in.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
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

  spex "stage_response works without polished_body; touchpoint stored with body=nil" do
    scenario "stage without body → row has body=nil; update later fills it in" do
      given_ "a fresh thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "nobody470"})
        {:ok, Map.merge(context, %{scope: scope, frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages with only thread_id + angle + synopsis (no polished_body), then later fills body via update_touchpoint", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              angle: "Lead with the harness-vs-chat split",
              synopsis: "OP catalogs four context tools but doesn't address structured-layer rot."
            },
            context.frame
          )

        touchpoint_id = (decode_payload(stage_resp))["touchpoint_id"]
        refute is_nil(touchpoint_id), "expected touchpoint_id in stage_response payload"

        {:ok, after_stage} = Engagements.get_touchpoint_by_id(context.scope, touchpoint_id)

        {:reply, _update_resp, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: touchpoint_id,
              polished_body: "Now that Sam dictated his take, here's the polished version."
            },
            context.frame
          )

        {:ok, after_update} = Engagements.get_touchpoint_by_id(context.scope, touchpoint_id)

        {:ok, Map.merge(context, %{after_stage: after_stage, after_update: after_update})}
      end

      then_ "stage creates the row with body=nil + state=:staged; later update fills body", context do
        assert context.after_stage.polished_body == nil,
               "expected polished_body nil on initial stage without body; got: #{inspect(context.after_stage.polished_body)}"

        assert context.after_stage.state == :staged,
               "expected state :staged; got: #{inspect(context.after_stage.state)}"

        assert context.after_stage.angle == "Lead with the harness-vs-chat split",
               "expected angle persisted; got: #{inspect(context.after_stage.angle)}"

        assert context.after_update.polished_body ==
                 "Now that Sam dictated his take, here's the polished version.",
               "expected body filled in by update; got: #{inspect(context.after_update.polished_body)}"

        assert context.after_update.state == :staged,
               "expected state still :staged after body fill-in; got: #{inspect(context.after_update.state)}"

        {:ok, context}
      end
    end
  end
end
