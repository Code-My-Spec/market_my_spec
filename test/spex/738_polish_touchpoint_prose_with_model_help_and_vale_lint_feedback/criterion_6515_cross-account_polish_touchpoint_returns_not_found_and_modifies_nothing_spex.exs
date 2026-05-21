defmodule MarketMySpecSpex.Story738.Criterion6515Spex do
  @moduledoc """
  Story 738 — Polish Touchpoint prose with model help and Vale lint feedback
  Criterion 6515 — Cross-account polish_touchpoint returns :not_found and
  modifies nothing.

  Account A owns a staged Touchpoint. Account B's agent calls
  polish_touchpoint with A's touchpoint_id. The call must return
  :not_found (error response, no data leak) and leave A's Touchpoint
  unchanged — its polished_body must remain whatever it was before
  (nil, on a freshly-staged Touchpoint).

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

  spex "cross-account polish_touchpoint is rejected and modifies nothing" do
    scenario "Account A owns Touchpoint; Account B's agent calls polish_touchpoint with A's id → :not_found" do
      given_ "Account A has a staged Touchpoint; Account B is a separate account", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        scope_b = Fixtures.account_scoped_user_fixture()
        frame_a = build_frame(scope_a)
        frame_b = build_frame(scope_b)

        thread_a =
          Fixtures.thread_fixture(scope_a, %{
            source: :reddit,
            source_thread_id: "rt6515",
            subreddit: "elixir"
          })

        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: thread_a.id,
              synopsis: "OP synopsis A.",
              angle: "Angle A."
            },
            frame_a
          )

        touchpoint_id = (decode_payload(stage_resp))["touchpoint_id"]

        {:ok,
         Map.merge(context, %{
           frame_a: frame_a,
           frame_b: frame_b,
           thread_a: thread_a,
           touchpoint_id: touchpoint_id
         })}
      end

      when_ "Account B's agent calls polish_touchpoint targeting Account A's touchpoint_id", context do
        {:reply, polish_resp, _} =
          PolishTouchpoint.execute(
            %{
              touchpoint_id: context.touchpoint_id,
              polished_body: "Attacker-attempted polished body."
            },
            context.frame_b
          )

        {:reply, list_a, _} =
          ListTouchpoints.execute(%{thread_id: context.thread_a.id}, context.frame_a)

        touchpoints_a =
          (decode_payload(list_a))["touchpoints"] ||
            (decode_payload(list_a))["list"] || []

        tp_on_a = Enum.find(touchpoints_a, &((&1["id"] || &1[:id]) == context.touchpoint_id))

        {:ok, Map.merge(context, %{polish_resp: polish_resp, tp_on_a: tp_on_a})}
      end

      then_ "the response is an error and Account A's Touchpoint is unchanged", context do
        case context.polish_resp do
          %Response{isError: true} ->
            :ok

          other ->
            flunk("expected cross-account polish_touchpoint rejection, got: #{inspect(other)}")
        end

        body = decode_payload(context.polish_resp)
        json = Jason.encode!(body)

        refute String.contains?(json, "Attacker-attempted polished body"),
               "expected no leak of attacker prose in error response: #{json}"

        assert context.tp_on_a, "expected Account A's Touchpoint still present"

        polished_body = context.tp_on_a["polished_body"] || context.tp_on_a[:polished_body]

        assert polished_body == nil,
               "expected Account A's polished_body unchanged (nil) after attacker attempt; got: #{inspect(polished_body)}"

        {:ok, context}
      end
    end
  end
end
