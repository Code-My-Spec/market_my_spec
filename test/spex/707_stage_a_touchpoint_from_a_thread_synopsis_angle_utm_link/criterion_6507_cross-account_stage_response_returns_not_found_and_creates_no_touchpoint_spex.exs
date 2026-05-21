defmodule MarketMySpecSpex.Story707.Criterion6507Spex do
  @moduledoc """
  Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)
  Criterion 6507 — Cross-account stage_response returns :not_found and
  creates no Touchpoint.

  Account A owns a Thread. Account B's agent calls stage_response
  targeting A's thread_id. The call must return :not_found (an error
  response, no leak of A's data) and create no Touchpoint on either
  account.

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

  spex "cross-account stage_response is rejected; no Touchpoint is created" do
    scenario "Account B targets Account A's thread_id → :not_found and A has zero touchpoints" do
      given_ "Account A owns a Thread; Account B is a separate account", context do
        scope_a = Fixtures.account_scoped_user_fixture()

        thread_a =
          Fixtures.thread_fixture(scope_a, %{
            source: :reddit,
            source_thread_id: "rt6507",
            subreddit: "elixir"
          })

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
              synopsis: "Attacker-attempted synopsis (should not be persisted).",
              angle: "Attacker-attempted angle."
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

      then_ "the response is an error and Account A's Thread has zero touchpoints", context do
        case context.stage_resp do
          %Response{isError: true} ->
            :ok

          other ->
            flunk("expected cross-account stage_response rejection, got: #{inspect(other)}")
        end

        body = decode_payload(context.stage_resp)
        json = Jason.encode!(body)

        refute String.contains?(json, "rt6507"),
               "expected no leak of Account A's source_thread_id in error response: #{json}"

        touchpoints = context.a_payload["touchpoints"] || context.a_payload["list"] || []

        assert touchpoints == [],
               "expected zero Touchpoints on Account A after cross-account attempt; got: #{inspect(touchpoints)}"

        {:ok, context}
      end
    end
  end
end
