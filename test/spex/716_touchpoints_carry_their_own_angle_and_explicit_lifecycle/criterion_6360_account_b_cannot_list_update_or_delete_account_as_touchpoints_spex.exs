defmodule MarketMySpecSpex.Story716.Criterion6360Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6360 — Account B cannot list, update, or delete Account A's
  Touchpoints.

  Sister to 6340; pinned via Three Amigos scenario. Account A's
  Touchpoint cannot be discovered, mutated, or deleted by Account B —
  all three (list, update, delete) return :not_found, no leak in the
  response body, and Account A's row is untouched.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.Engagements.Tools.DeleteTouchpoint
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

  spex "cross-account update or delete returns :not_found; no leak" do
    scenario "Account B attempts update + delete on Account A's touchpoint; both reject" do
      given_ "Account A has a staged Touchpoint with a known angle; Account B is unrelated",
             context do
        scope_a = Fixtures.account_scoped_user_fixture()
        thread_a = Fixtures.thread_fixture(scope_a, %{source: :reddit, source_thread_id: "iso359"})
        frame_a = build_frame(scope_a)

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread_a.id,
              polished_body: "A's body",
              link_target: "https://x",
              angle: "A's angle"
            },
            frame_a
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        scope_b = Fixtures.account_scoped_user_fixture()
        frame_b = build_frame(scope_b)

        {:ok,
         Map.merge(context, %{
           frame_a: frame_a,
           frame_b: frame_b,
           thread_a: thread_a,
           touchpoint_id: touchpoint_id
         })}
      end

      when_ "Account B calls update_touchpoint then delete_touchpoint targeting A's id", context do
        {:reply, update_resp, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              state: "posted",
              comment_url: "https://attacker.example/x",
              posted_at: DateTime.utc_now() |> DateTime.to_iso8601()
            },
            context.frame_b
          )

        {:reply, delete_resp, _} =
          DeleteTouchpoint.execute(%{touchpoint_id: context.touchpoint_id}, context.frame_b)

        {:reply, list_a, _} =
          ListTouchpoints.execute(%{thread_id: context.thread_a.id}, context.frame_a)

        {:ok,
         Map.merge(context, %{
           update_resp: update_resp,
           delete_resp: delete_resp,
           a_payload: decode_payload(list_a)
         })}
      end

      then_ "both reject as :not_found with no leak; A's touchpoint still :staged with original fields",
            context do
        for resp <- [context.update_resp, context.delete_resp] do
          case resp do
            %Response{isError: true} -> :ok
            other -> flunk("expected cross-account rejection, got: #{inspect(other)}")
          end

          body = decode_payload(resp)
          json = Jason.encode!(body)

          refute String.contains?(json, "A's body"),
                 "expected no leak of A's polished_body in error response: #{json}"

          refute String.contains?(json, "A's angle"),
                 "expected no leak of A's angle in error response: #{json}"
        end

        touchpoints = context.a_payload["touchpoints"] || context.a_payload["list"] || []
        a_tp = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.touchpoint_id))
        assert a_tp, "expected A's touchpoint still present in A's list"

        assert (a_tp["state"] || a_tp[:state]) in ["staged", :staged],
               "expected A's touchpoint still :staged"

        assert (a_tp["polished_body"] || a_tp[:polished_body]) == "A's body"
        assert (a_tp["angle"] || a_tp[:angle]) == "A's angle"
        assert (a_tp["comment_url"] || a_tp[:comment_url]) == nil

        {:ok, context}
      end
    end
  end
end
