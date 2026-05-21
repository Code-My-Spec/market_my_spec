defmodule MarketMySpecSpex.Story738.Criterion6510Spex do
  @moduledoc """
  Story 738 — Polish Touchpoint prose with model help and Vale lint feedback
  Criterion 6510 — polish_touchpoint writes polished_body onto the named
  Touchpoint.

  With no Vale config saved on the account, the lint returns empty alerts
  (per R3), which satisfies R2a's "writes only when no alerts" condition.
  So an agent staging a fresh Touchpoint then calling polish_touchpoint
  with a polished body sees that body persisted on the Touchpoint —
  observable via list_touchpoints.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints
  alias MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint
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

  spex "polish_touchpoint writes polished_body onto the named Touchpoint" do
    scenario "Stage a Touchpoint → polish_touchpoint with a body → body is persisted" do
      given_ "Sam has a staged Touchpoint on a Reddit thread (no Vale config)", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "rt6510",
            subreddit: "elixir"
          })

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              synopsis: "OP asks about something innocuous.",
              angle: "Point to existing community resources."
            },
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:ok, Map.merge(context, %{frame: frame, thread: thread, touchpoint_id: touchpoint_id})}
      end

      when_ "agent calls polish_touchpoint with a polished body", context do
        polished_body = "A measured reply that adds context without violating any voice rule."

        {:reply, _polish_resp, _} =
          PolishTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, polished_body: polished_body},
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        touchpoints =
          (decode_payload(list_resp))["touchpoints"] ||
            (decode_payload(list_resp))["list"] || []

        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))

        {:ok, Map.merge(context, %{polished_body: polished_body, touchpoint: tp})}
      end

      then_ "the Touchpoint's polished_body equals the body the agent passed", context do
        assert context.touchpoint, "expected the polished touchpoint in list_touchpoints"

        stored = context.touchpoint["polished_body"] || context.touchpoint[:polished_body]

        assert stored == context.polished_body,
               "expected polished_body persisted verbatim; got: #{inspect(stored)}"

        {:ok, context}
      end
    end
  end
end
