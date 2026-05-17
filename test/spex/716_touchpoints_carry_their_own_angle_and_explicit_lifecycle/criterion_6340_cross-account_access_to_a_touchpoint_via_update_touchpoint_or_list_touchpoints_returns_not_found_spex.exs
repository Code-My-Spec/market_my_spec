defmodule MarketMySpecSpex.Story716.Criterion6340Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6340 — Cross-account access to a touchpoint via
  `update_touchpoint` or `list_touchpoints` returns `:not_found` and
  never leaks data.

  Account A stages a touchpoint on its thread. Account B (different
  scope) calls list_touchpoints + update_touchpoint with A's IDs. Both
  return error/not_found. No leak of A's polished_body / angle.

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

  defp response_text(%Response{content: parts}) when is_list(parts) do
    Enum.map_join(parts, "", fn
      %{"text" => t} -> t
      %{text: t} -> t
      other -> inspect(other)
    end)
  end

  spex "cross-account list/update return :not_found and never leak data" do
    scenario "Account B calls list_touchpoints + update_touchpoint with Account A's IDs" do
      given_ "Account A's staged Touchpoint with sensitive body/angle and Account B's frame",
             context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()
        frame_a = build_frame(scope_a)
        frame_b = build_frame(scope_b)

        thread_a =
          Fixtures.thread_fixture(scope_a, %{source: :reddit, source_thread_id: "iso001"})

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread_a.id,
              polished_body: "ACCOUNT_A_PRIVATE_BODY",
              link_target: "https://marketmyspec.com/x",
              angle: "ACCOUNT_A_PRIVATE_ANGLE"
            },
            frame_a
          )

        touchpoint_id =
          (decode_payload(stage_resp))["touchpoint_id"] ||
            (decode_payload(stage_resp))["id"]

        {:ok,
         Map.merge(context, %{
           frame_b: frame_b,
           thread_a_id: thread_a.id,
           touchpoint_id: touchpoint_id
         })}
      end

      when_ "Account B's frame calls list and update on A's IDs", context do
        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread_a_id}, context.frame_b)

        {:reply, update_resp, _} =
          UpdateTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              state: "posted",
              comment_url: "https://x",
              posted_at: DateTime.utc_now() |> DateTime.to_iso8601()
            },
            context.frame_b
          )

        {:ok, Map.merge(context, %{list_resp: list_resp, update_resp: update_resp})}
      end

      then_ "both return error/empty AND no leak of A's body or angle in response text",
            context do
        # list_touchpoints from Account B — either :not_found or empty list, no leakage
        list_text = response_text(context.list_resp)
        refute list_text =~ "ACCOUNT_A_PRIVATE_BODY",
               "expected no leak of A's polished_body via list_touchpoints"
        refute list_text =~ "ACCOUNT_A_PRIVATE_ANGLE",
               "expected no leak of A's angle via list_touchpoints"

        # If list returned a list, it must be empty (B has no touchpoints on this thread)
        list_payload = decode_payload(context.list_resp)
        if Map.has_key?(list_payload, "touchpoints") do
          touchpoints = list_payload["touchpoints"] || []
          assert touchpoints == [],
                 "expected empty touchpoints list for cross-account thread, got: #{inspect(touchpoints)}"
        end

        # update_touchpoint from Account B must fail
        case context.update_resp do
          %Response{isError: true} = resp ->
            update_text = response_text(resp)
            refute update_text =~ "ACCOUNT_A_PRIVATE_BODY"
            refute update_text =~ "ACCOUNT_A_PRIVATE_ANGLE"

          %Response{isError: false} = resp ->
            flunk("expected update_touchpoint to error cross-account, got success: #{inspect(resp)}")

          other ->
            flunk("unexpected update_touchpoint response: #{inspect(other)}")
        end

        {:ok, context}
      end
    end
  end
end
