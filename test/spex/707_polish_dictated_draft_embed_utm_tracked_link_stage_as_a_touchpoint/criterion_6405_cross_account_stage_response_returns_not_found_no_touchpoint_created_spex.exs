defmodule MarketMySpecSpex.Story707.Criterion6405Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6405 — Cross-account access — calling `stage_response`
  with a thread_id owned by a different account returns `:not_found`;
  no Touchpoint is created.

  Account isolation: Account A owns the Thread; Account B's
  stage_response call with A's thread_id is rejected as :not_found.
  Critical: no Touchpoint is created on EITHER account — not on A,
  not on B's scope.

  Interaction surface: MCP tool execution (agent surface).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
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

  spex "cross-account stage_response returns :not_found; no Touchpoint created" do
    scenario "Account B's stage call on Account A's Thread → :not_found; A and B both empty" do
      given_ "Account A has a persisted Thread; Account B is unrelated", context do
        scope_a = Fixtures.account_scoped_user_fixture()
        thread_a = Fixtures.thread_fixture(scope_a, %{source: :reddit, source_thread_id: "iso405"})

        scope_b = Fixtures.account_scoped_user_fixture()

        {:ok,
         Map.merge(context, %{
           frame_a: build_frame(scope_a),
           frame_b: build_frame(scope_b),
           thread_a: thread_a
         })}
      end

      when_ "Account B calls stage_response targeting Account A's thread_id", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread_a.id,
              polished_body: "Attacker body",
              link_target: "https://attacker.example/x"
            },
            context.frame_b
          )

        {:reply, list_a, _} =
          ListTouchpoints.execute(%{thread_id: context.thread_a.id}, context.frame_a)

        {:ok,
         Map.merge(context, %{
           stage_resp: stage_resp,
           a_payload: decode_payload(list_a)
         })}
      end

      then_ "stage_response returns :not_found; Account A's thread has zero Touchpoints", context do
        case context.stage_resp do
          %Response{isError: true} -> :ok
          other -> flunk("expected cross-account stage_response rejection, got: #{inspect(other)}")
        end

        body = decode_payload(context.stage_resp)
        json = Jason.encode!(body)

        refute String.contains?(json, "Attacker body"),
               "expected no leak of attacker body in error response: #{json}"

        touchpoints = context.a_payload["touchpoints"] || context.a_payload["list"] || []

        assert touchpoints == [],
               "expected zero Touchpoints on Account A after cross-account attempt; got: #{inspect(touchpoints)}"

        {:ok, context}
      end
    end
  end
end
