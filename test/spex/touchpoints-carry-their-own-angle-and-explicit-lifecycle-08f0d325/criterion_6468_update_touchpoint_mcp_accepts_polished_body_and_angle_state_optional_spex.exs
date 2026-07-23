defmodule MarketMySpecSpex.Story716.Criterion6468Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6468 — update_touchpoint MCP tool accepts optional
  :angle and :state (state no longer required); angle edits via the MCP
  tool persist identically to the LiveView Save form.

  polished_body is now written via the separate PolishTouchpoint tool
  (story 738 design).

  Scenario: MCP update_touchpoint with only angle (no state) →
  angle persists, state stays at :staged. Then PolishTouchpoint
  writes the polished_body.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.Engagements
  alias MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint
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

  spex "update_touchpoint writes angle; polish_touchpoint writes polished_body" do
    scenario "update_touchpoint with angle; then polish_touchpoint with body → both persist, state stays :staged" do
      given_ "a freshly staged touchpoint", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "upd468"})
        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              synopsis: "Initial discussion",
              angle: "initial angle"
            },
            frame
          )

        touchpoint_id = (decode_payload(stage_resp))["touchpoint_id"]

        {:ok, Map.merge(context, %{scope: scope, frame: frame, touchpoint_id: touchpoint_id})}
      end

      when_ "agent calls update_touchpoint with :angle, then polish_touchpoint with :polished_body", context do
        {:reply, _update_resp, _frame} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              angle: "revised MCP angle"
            },
            context.frame
          )

        {:reply, _polish_resp, _frame} =
          PolishTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              polished_body: "Revised body via Polish tool"
            },
            context.frame
          )

        {:ok, reloaded} = Engagements.get_touchpoint_by_id(context.scope, context.touchpoint_id)
        {:ok, Map.put(context, :reloaded, reloaded)}
      end

      then_ "both fields persist and the state remains :staged", context do
        assert context.reloaded.polished_body == "Revised body via Polish tool",
               "expected polished_body persisted via PolishTouchpoint; got: #{inspect(context.reloaded.polished_body)}"

        assert context.reloaded.angle == "revised MCP angle",
               "expected angle persisted via UpdateTouchpoint; got: #{inspect(context.reloaded.angle)}"

        assert context.reloaded.state == :staged,
               "expected state preserved as :staged when not passed; got: #{inspect(context.reloaded.state)}"

        {:ok, context}
      end
    end

  end
end
