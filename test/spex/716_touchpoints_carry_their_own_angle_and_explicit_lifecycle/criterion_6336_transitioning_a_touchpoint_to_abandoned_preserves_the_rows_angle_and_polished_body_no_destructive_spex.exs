defmodule MarketMySpecSpex.Story716.Criterion6336Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6336 — Transitioning a touchpoint to `:abandoned` preserves
  the row's angle and polished_body — no destructive delete.

  Stage with an angle, transition to :abandoned, then list_touchpoints
  must show the row with the original angle + polished_body intact
  (and new state :abandoned).

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

  spex "abandoned transition preserves angle + polished_body; non-destructive" do
    scenario "Touchpoint moves to :abandoned; row still queryable with original metadata" do
      given_ "a Touchpoint staged with angle + polished_body", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "abd001"})
        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Polished body — abandon test",
              link_target: "https://marketmyspec.com/x",
              angle: "Original angle to preserve"
            },
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:ok, Map.merge(context, %{frame: frame, thread: thread, touchpoint_id: touchpoint_id})}
      end

      when_ "agent transitions to :abandoned and lists touchpoints", context do
        {:reply, _update_resp, _} =
          UpdateTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, state: "abandoned"},
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :list_payload, decode_payload(list_resp))}
      end

      then_ "row exists with state :abandoned, original angle and polished_body preserved",
            context do
        touchpoints = context.list_payload["touchpoints"] || context.list_payload["list"] || []

        refute Enum.empty?(touchpoints),
               "expected the abandoned Touchpoint still present (no destructive delete)"

        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected to find the abandoned touchpoint"

        assert (tp["state"] || tp[:state]) in ["abandoned", :abandoned],
               "expected state :abandoned, got: #{inspect(tp["state"] || tp[:state])}"

        assert (tp["angle"] || tp[:angle]) == "Original angle to preserve",
               "expected original angle preserved, got: #{inspect(tp["angle"] || tp[:angle])}"

        assert (tp["polished_body"] || tp[:polished_body]) == "Polished body — abandon test",
               "expected polished_body preserved, got: #{inspect(tp["polished_body"] || tp[:polished_body])}"

        {:ok, context}
      end
    end
  end
end
