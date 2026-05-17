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

  spex "stage_response accepts optional angle; persists string when given, nil when omitted" do
    scenario "with angle: persisted; without angle: nil" do
      given_ "an account with a thread", context do
        scope = Fixtures.account_scoped_user_fixture()
        thread = Fixtures.thread_fixture(scope, %{source: :reddit, source_thread_id: "ang334"})
        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "the agent stages once with angle and once without", context do
        {:reply, _r1, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "With angle body",
              link_target: "https://marketmyspec.com/x",
              angle: "Lead with the discovery insight"
            },
            context.frame
          )

        {:reply, _r2, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Without angle body",
              link_target: "https://marketmyspec.com/x"
            },
            context.frame
          )

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok, Map.put(context, :payload, decode_payload(list_resp))}
      end

      then_ "exactly two touchpoints exist; one with angle string, one with angle nil",
            context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []

        refute Enum.empty?(touchpoints), "expected 2 touchpoints, got empty"
        assert length(touchpoints) == 2, "expected 2, got #{length(touchpoints)}"

        with_angle =
          Enum.find(touchpoints, fn tp ->
            (tp["polished_body"] || tp[:polished_body]) == "With angle body"
          end)

        without_angle =
          Enum.find(touchpoints, fn tp ->
            (tp["polished_body"] || tp[:polished_body]) == "Without angle body"
          end)

        assert with_angle, "expected to find the with-angle touchpoint"
        assert without_angle, "expected to find the without-angle touchpoint"

        assert (with_angle["angle"] || with_angle[:angle]) == "Lead with the discovery insight",
               "expected angle persisted, got: #{inspect(with_angle["angle"] || with_angle[:angle])}"

        assert (without_angle["angle"] || without_angle[:angle]) == nil,
               "expected angle nil when omitted, got: #{inspect(without_angle["angle"] || without_angle[:angle])}"

        {:ok, context}
      end
    end
  end
end
