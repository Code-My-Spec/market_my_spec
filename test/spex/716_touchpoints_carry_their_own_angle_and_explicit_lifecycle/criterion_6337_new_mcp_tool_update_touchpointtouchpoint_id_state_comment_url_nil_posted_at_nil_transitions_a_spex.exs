defmodule MarketMySpecSpex.Story716.Criterion6337Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6337 — New MCP tool `update_touchpoint(touchpoint_id, state,
  comment_url \\\\ nil, posted_at \\\\ nil)` transitions a touchpoint
  between states.

  Stage → :posted (with comment_url + posted_at) → :abandoned. Each
  transition observable via list_touchpoints. Tests the tool surface +
  forward transitions.

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

  spex "update_touchpoint transitions states (staged → posted → abandoned)" do
    scenario "Two transitions observed via list_touchpoints between calls" do
      given_ "a freshly staged Touchpoint", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "up001"})
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

      when_ "the agent transitions :staged → :posted → :abandoned", context do
        # First transition: :posted (with required comment_url + posted_at)
        posted_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              state: "posted",
              comment_url: "https://www.reddit.com/r/elixir/comments/up001/_/xyz",
              posted_at: posted_at
            },
            context.frame
          )

        {:reply, list_after_posted, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        # Second transition: :abandoned
        {:reply, _, _} =
          UpdateTouchpoint.execute(
            %{touchpoint_id: context.touchpoint_id, state: "abandoned"},
            context.frame
          )

        {:reply, list_after_abandoned, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           after_posted: decode_payload(list_after_posted),
           after_abandoned: decode_payload(list_after_abandoned)
         })}
      end

      then_ "state is :posted after first transition; :abandoned after second", context do
        state_after_posted = current_state(context.after_posted, context.touchpoint_id)

        assert state_after_posted in ["posted", :posted],
               "expected :posted after first transition, got: #{inspect(state_after_posted)}"

        state_after_abandoned = current_state(context.after_abandoned, context.touchpoint_id)

        assert state_after_abandoned in ["abandoned", :abandoned],
               "expected :abandoned after second transition, got: #{inspect(state_after_abandoned)}"

        {:ok, context}
      end
    end
  end
end
