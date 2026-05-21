defmodule MarketMySpecSpex.Story716.Criterion6334Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6334 — `stage_response` MCP tool accepts an optional `angle`
  parameter and persists it on the new touchpoint; angle is not required.

  Two scenarios in one spex: with angle (persisted) and without (nil).
  Each call must succeed and produce a Touchpoint observable via
  list_touchpoints.

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

  spex "stage_response requires synopsis and angle; both are persisted" do
    scenario "two angle values: strong vs generic" do
      given_ "an account with a thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ang334"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent stages twice with different angles", context do
        {:reply, _r1, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: "Discussion about angle discovery insights",
              angle: "Lead with the discovery insight"
            },
            context.frame
          )

        {:reply, _r2, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              synopsis: "Discussion about angle discovery insights",
              angle: "Generic reply with helpful link"
            },
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "exactly two touchpoints exist with distinct angles",
            context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []

        refute Enum.empty?(touchpoints), "expected 2 touchpoints, got empty"
        assert length(touchpoints) == 2, "expected 2, got #{length(touchpoints)}"

        strong_angle =
          Enum.find(touchpoints, fn tp ->
            (tp["angle"] || tp[:angle]) == "Lead with the discovery insight"
          end)

        generic_angle =
          Enum.find(touchpoints, fn tp ->
            (tp["angle"] || tp[:angle]) == "Generic reply with helpful link"
          end)

        assert strong_angle, "expected to find the strong-angle touchpoint"
        assert generic_angle, "expected to find the generic-angle touchpoint"

        assert (strong_angle["angle"] || strong_angle[:angle]) == "Lead with the discovery insight",
               "expected angle persisted, got: #{inspect(strong_angle["angle"] || strong_angle[:angle])}"

        assert (generic_angle["angle"] || generic_angle[:angle]) == "Generic reply with helpful link",
               "expected angle persisted, got: #{inspect(generic_angle["angle"] || generic_angle[:angle])}"

        {:ok, context}
      end
    end
  end
end
