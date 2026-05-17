defmodule MarketMySpecSpex.Story716.Criterion6335Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6335 — Transitioning a touchpoint to `:posted` requires
  comment_url and posted_at; the changeset rejects the transition
  otherwise.

  Stage a Touchpoint, then call update_touchpoint with state: "posted"
  but no comment_url. Expect an error response. The touchpoint must stay
  in :staged (verified via list_touchpoints).

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

  spex "posted transition requires comment_url + posted_at; rejected otherwise" do
    scenario "update to :posted without comment_url returns error; row stays :staged" do
      given_ "an account with a Thread and a freshly-staged Touchpoint", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "rej001"})
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

      when_ "the agent calls update_touchpoint with state :posted but no comment_url",
            context do
        {:reply, update_resp, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              state: "posted"
              # NO comment_url, NO posted_at
            },
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           update_response: update_resp,
           list_payload: decode_payload(list_resp)
         })}
      end

      then_ "update_touchpoint returns an error; the touchpoint stays :staged in list_touchpoints",
            context do
        # Update should fail
        case context.update_response do
          %Response{isError: true} ->
            :ok

          %Response{isError: false} = resp ->
            flunk("expected update_touchpoint to error, got success: #{inspect(resp)}")

          other ->
            flunk("unexpected update response: #{inspect(other)}")
        end

        # The touchpoint should still be :staged
        touchpoints =
          context.list_payload["touchpoints"] || context.list_payload["list"] || []

        refute Enum.empty?(touchpoints), "expected the touchpoint still listed"

        [tp | _] = touchpoints
        state = tp["state"] || tp[:state]

        assert state in ["staged", :staged],
               "expected state :staged after failed transition, got: #{inspect(state)}"

        {:ok, context}
      end
    end
  end
end
