defmodule MarketMySpecSpex.Story707.Criterion6413Spex do
  @moduledoc """
  Story 707 — Polish dictated draft, embed UTM-tracked link, stage as
  a Touchpoint
  Criterion 6413 — Touchpoint defaults to :staged; angle persists when
  provided, nil when omitted.

  Sister to 6399 (angle) + 6400 (default state); pinned via Three
  Amigos scenario. Combined assertion: in the same flow, defaults +
  optional-angle behavior both hold.

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

  spex "defaults: state :staged; angle present when given, nil when not" do
    scenario "Two stages (with/without angle) — both :staged, angle differs as expected" do
      given_ "a Reddit Thread", context do
        scope = Fixtures.account_scoped_user_fixture()

        thread =
          Fixtures.thread_fixture(scope, %{
            source: :reddit,
            source_thread_id: "def413",
            subreddit: "elixir"
          })

        {:ok, Map.merge(context, %{frame: build_frame(scope), thread: thread})}
      end

      when_ "two stages — one with angle, one without — and list", context do
        {:reply, no_angle_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Body 1 https://x",
              link_target: "https://x"
            },
            context.frame
          )

        {:reply, with_angle_resp, _} =
          StageResponse.execute(
            %{
              thread_id: context.thread.id,
              polished_body: "Body 2 https://x",
              link_target: "https://x",
              angle: "explicit angle string"
            },
            context.frame
          )

        no_angle_id =
          (decode_payload(no_angle_resp))["touchpoint_id"] ||
            (decode_payload(no_angle_resp))["id"]

        with_angle_id =
          (decode_payload(with_angle_resp))["touchpoint_id"] ||
            (decode_payload(with_angle_resp))["id"]

        {:reply, list_resp, _} =
          ListTouchpoints.execute(%{thread_id: context.thread.id}, context.frame)

        {:ok,
         Map.merge(context, %{
           no_angle_id: no_angle_id,
           with_angle_id: with_angle_id,
           payload: decode_payload(list_resp)
         })}
      end

      then_ "both rows are :staged; with-angle row carries angle string; without-angle carries nil",
            context do
        touchpoints = context.payload["touchpoints"] || context.payload["list"] || []
        assert length(touchpoints) == 2

        no_angle = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.no_angle_id))
        with_angle = Enum.find(touchpoints, &((&1["id"] || &1[:id]) == context.with_angle_id))

        assert no_angle, "expected no-angle touchpoint in list"
        assert with_angle, "expected with-angle touchpoint in list"

        # Both default to :staged
        for {tp, label} <- [{no_angle, "no-angle"}, {with_angle, "with-angle"}] do
          assert (tp["state"] || tp[:state]) in ["staged", :staged],
                 "expected #{label} touchpoint default state :staged, got: #{inspect(tp["state"] || tp[:state])}"
        end

        # angle behavior
        assert (no_angle["angle"] || no_angle[:angle]) == nil,
               "expected nil angle when omitted; got: #{inspect(no_angle["angle"] || no_angle[:angle])}"

        assert (with_angle["angle"] || with_angle[:angle]) == "explicit angle string",
               "expected angle persisted verbatim; got: #{inspect(with_angle["angle"] || with_angle[:angle])}"

        {:ok, context}
      end
    end
  end
end
