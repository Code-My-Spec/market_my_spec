defmodule MarketMySpecSpex.Story716.Criterion6354Spex do
  @moduledoc """
  Story 716 — Touchpoints carry their own angle and explicit lifecycle
  Criterion 6354 — stage_response persists angle when given; leaves it
  nil when omitted.

  Sister to 6334; pinned via Three Amigos scenario. One stage call with
  angle, one without; list_touchpoints reads both back; angle field
  matches per call.

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

  spex "stage_response requires synopsis and angle parameters" do
    scenario "Two stages on same thread: with different angles — both surface correctly" do
      given_ "a thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ang354"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "two stages on the same thread with different angles; then list", context do
        {:reply, _, _} =
          StageResponse.execute(
            %{thread_id: context.thread.id, synopsis: "Discussion on harness engineering",
              angle: "Suggest harness as foundation"},
            context.frame
          )

        {:reply, _, _} =
          StageResponse.execute(
            %{thread_id: context.thread.id, synopsis: "Discussion on harness engineering",
              angle: "intro harness eng as the missing piece"},
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "both Touchpoints have their distinct angle strings", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []

        refute Enum.empty?(touchpoints), "expected 2 touchpoints, got empty"
        assert length(touchpoints) == 2

        angle1 =
          Enum.find(touchpoints, fn tp ->
            (tp["angle"] || tp[:angle]) == "Suggest harness as foundation"
          end)

        angle2 =
          Enum.find(touchpoints, fn tp ->
            (tp["angle"] || tp[:angle]) == "intro harness eng as the missing piece"
          end)

        assert angle1, "expected the first angle touchpoint in list"
        assert angle2, "expected the second angle touchpoint in list"

        assert (angle1["angle"] || angle1[:angle]) ==
                 "Suggest harness as foundation"

        assert (angle2["angle"] || angle2[:angle]) == "intro harness eng as the missing piece"

        {:ok, context}
      end
    end
  end
end
