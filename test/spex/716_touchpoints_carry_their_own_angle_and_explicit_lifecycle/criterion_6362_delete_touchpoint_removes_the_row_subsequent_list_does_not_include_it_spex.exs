defmodule MarketMySpecSpex.Story716.Criterion6362Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6362 — delete_touchpoint removes the row; subsequent list
  does not include it.

  Sister to 6339; pinned via Three Amigos scenario. Hard delete: post-
  delete list_touchpoints omits the id (no `:deleted` state, no tombstone).

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.DeleteTouchpoint
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

  spex "delete_touchpoint hard-removes the record (no tombstone)" do
    scenario "Stage two; delete one; list contains the other only" do
      given_ "two staged Touchpoints on the same thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "del358"})
        frame = build_frame(scope)

        {:reply, stage_a, _} =
          StageResponse.execute(
            %{thread_id: thread.id, polished_body: "Keep me", link_target: "https://x"},
            frame
          )

        {:reply, stage_b, _} =
          StageResponse.execute(
            %{thread_id: thread.id, polished_body: "Delete me", link_target: "https://x"},
            frame
          )

        a_id = (decode_payload(stage_a))["touchpoint_id"] || (decode_payload(stage_a))["id"]
        b_id = (decode_payload(stage_b))["touchpoint_id"] || (decode_payload(stage_b))["id"]

        {:ok,
         Map.merge(context, %{
           frame: frame,
           thread: thread,
           keep_id: a_id,
           delete_id: b_id
         })}
      end

      when_ "agent calls delete_touchpoint on the second", context do
        {:reply, _, _} =
          DeleteTouchpoint.execute(%{touchpoint_id: context.delete_id}, context.frame)

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "list returns the surviving touchpoint only; deleted id is absent (no soft marker)",
            context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        ids = Enum.map(touchpoints, &(&1["id"] || &1[:id]))

        assert context.keep_id in ids, "expected surviving touchpoint to remain in list"

        refute context.delete_id in ids,
               "expected deleted touchpoint absent — got id still in list: #{inspect(ids)}"

        refute Enum.any?(touchpoints, fn tp ->
                 state = tp["state"] || tp[:state]
                 state in ["deleted", :deleted]
               end),
               "expected no :deleted tombstone state — touchpoints: #{inspect(touchpoints)}"

        {:ok, context}
      end
    end
  end
end
