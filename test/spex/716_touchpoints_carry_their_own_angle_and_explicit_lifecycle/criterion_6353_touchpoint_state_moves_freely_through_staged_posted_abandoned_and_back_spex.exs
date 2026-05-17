defmodule MarketMySpecSpex.Story716.Criterion6353Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6353 — Touchpoint state moves freely through staged,
  posted, abandoned, and back.

  Full bidirectional lifecycle: :staged → :posted → :abandoned →
  :staged. Each transition observable via list_touchpoints. Touchpoint
  id, angle, polished_body unchanged across all transitions.

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

  defp current_state(payload, touchpoint_id) do
    touchpoints = payload["touchpoints"] || payload["list"] || []
    tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == touchpoint_id))
    if tp, do: tp["state"] || tp[:state], else: nil
  end

  spex "state moves freely staged → posted → abandoned → staged" do
    scenario "Full lifecycle including backward transition; id/angle/polished_body preserved" do
      given_ "a Touchpoint staged with a known angle + polished_body", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "lc001"})
        frame = build_frame(scope)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread.id,
              polished_body: "Lifecycle test body",
              link_target: "https://x",
              angle: "Lifecycle test angle"
            },
            frame
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:ok, Map.merge(context, %{frame: frame, thread: thread, touchpoint_id: touchpoint_id})}
      end

      when_ "agent moves through :posted → :abandoned → :staged", context do
        posted_at = DateTime.utc_now() |> DateTime.to_iso8601()

        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              state: "posted",
              comment_url: "https://www.reddit.com/r/elixir/comments/lc001/_/xyz",
              posted_at: posted_at
            },
            context.frame
          )

        {:reply, list_after_posted, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, state: "abandoned"},
            context.frame
          )

        {:reply, list_after_abandoned, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, state: "staged"},
            context.frame
          )

        {:reply, list_after_back, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           after_posted: decode_payload(list_after_posted),
           after_abandoned: decode_payload(list_after_abandoned),
           after_back: decode_payload(list_after_back)
         })}
      end

      then_ "states are posted, abandoned, staged across the three list calls; metadata unchanged",
            context do
        assert current_state(context.after_posted, context.touchpoint_id) in ["posted", :posted]
        assert current_state(context.after_abandoned, context.touchpoint_id) in ["abandoned", :abandoned]
        assert current_state(context.after_back, context.touchpoint_id) in ["staged", :staged]

        # Verify metadata stays through transitions
        touchpoints = context.after_back["touchpoints"] || context.after_back["list"] || []
        tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert tp, "expected touchpoint still in list after back-transition"

        assert (tp["polished_body"] || tp[:polished_body]) == "Lifecycle test body",
               "expected polished_body unchanged across transitions"

        assert (tp["angle"] || tp[:angle]) == "Lifecycle test angle",
               "expected angle unchanged across transitions"

        {:ok, context}
      end
    end
  end
end
