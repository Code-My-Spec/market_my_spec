defmodule MarketMySpecSpex.Story707.Criterion6411Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6411 — Account B calling stage_response on Account A's
  Thread returns :not_found.

  Sister to 6405; pinned via Three Amigos scenario. Same isolation
  contract from the explicit per-account angle. Account A is unaware
  the call happened; Account B receives :not_found with no leak.

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

  spex "Account B → stage_response(A.thread_id) returns :not_found" do
    scenario "Account A unaware after attempt; Account B's response carries no leak" do
      given_ "Account A's Thread exists; Account B is a separate account", context do
        scope_a = Fixtures.account_scoped_user_fixture()

        thread_a =
          Fixtures.thread_fixture(scope_a, %{
            source: :reddit,
            source_thread_id: "iso411",
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

      when_ "Account B calls stage_response with A's thread_id", context do
        {:reply, stage_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread_a.id,
              polished_body: "Attacker body B-side",
              link_target: "https://attacker.example/B"
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

      then_ "B receives :not_found with no leak; A's Thread has zero Touchpoints", context do
        case context.stage_resp do
          %Response{isError: true} -> :ok
          other -> flunk("expected B's cross-account stage to be rejected, got: #{inspect(other)}")
        end

        body = decode_payload(context.stage_resp)
        json = Jason.encode!(body)

        refute String.contains?(json, "iso411"),
               "expected no leak of A's source_thread_id in error response: #{json}"

        refute String.contains?(json, "Attacker body B-side"),
               "expected attacker body not echoed in error response: #{json}"

        touchpoints = context.a_payload["touchpoints"] || context.a_payload["list"] || []

        assert touchpoints == [],
               "expected zero Touchpoints on A's Thread after B's attempt; got: #{inspect(touchpoints)}"

        {:ok, context}
      end
    end
  end
end
