defmodule MarketMySpecSpex.Story707.Criterion6399Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6399 — `angle` is an optional fourth argument; when
  provided it is persisted on the Touchpoint per story 716 R2; when
  omitted the Touchpoint's angle is nil.

  Two stages on the same thread: one with angle, one without.
  list_touchpoints reads both back; the with-angle row has the angle
  string verbatim, the without-angle row has nil.

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

  spex "angle optional: persisted when given, nil when omitted" do
    scenario "Two stages — one with angle, one without — both surface correctly" do
      given_ "a persisted Thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ang399"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "agent stages twice — once with angle, once without — then lists", context do
        {:reply, _, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Body without angle https://x",
              link_target: "https://x"
            },
            context.frame
          )

        {:reply, _, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Body with angle https://x",
              link_target: "https://x",
              angle: "harness engineering as the missing piece"
            },
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "with-angle row carries the angle string; without-angle row has nil angle", context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        refute Enum.empty?(touchpoints), "expected 2 touchpoints, got empty list"
        assert length(touchpoints) == 2

        with_angle =
          Enum.find(touchpoints, fn tp ->
            String.contains?(tp["polished_body"] || tp[:polished_body] || "", "Body with angle")
          end)

        without_angle =
          Enum.find(touchpoints, fn tp ->
            String.contains?(tp["polished_body"] || tp[:polished_body] || "", "Body without angle")
          end)

        assert with_angle, "expected the with-angle touchpoint in list"
        assert without_angle, "expected the without-angle touchpoint in list"

        assert (with_angle["angle"] || with_angle[:angle]) ==
                 "harness engineering as the missing piece"

        assert (without_angle["angle"] || without_angle[:angle]) == nil,
               "expected angle nil when omitted, got: #{inspect(without_angle["angle"] || without_angle[:angle])}"

        {:ok, context}
      end
    end
  end
end
