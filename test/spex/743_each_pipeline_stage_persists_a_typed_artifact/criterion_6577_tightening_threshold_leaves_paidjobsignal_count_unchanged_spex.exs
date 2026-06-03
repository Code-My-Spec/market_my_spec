defmodule MarketMySpecSpex.Story743.Criterion6577Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6577 — Tightening threshold leaves PaidJobSignal count unchanged.

  PaidJobSignal is created once per JobPosting and updated in place when
  the money_gate threshold changes. Tightening the threshold reclassifies
  many PaidJobSignals from gated_in to gated_out, but the total count
  remains constant.

  Interaction surface: MCP tool execution; compare PaidJobSignal count
  via GetFrame artifact summary before and after a threshold tightening.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.UpdateFrame
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.ProblemDiscoveryHelpers

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

  defp pjs_count(payload) do
    artifacts = payload["artifacts"] || %{}
    artifacts["PaidJobSignal"] || 0
  end

  spex "Tightening the threshold leaves PaidJobSignal count constant" do
    scenario "Re-Score after tightening money_gate produces identical PaidJobSignal count" do
      given_ "a Frame scored with lenient money_gate; PaidJobSignal count recorded", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6577", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "PJS count under threshold change",
                  saved_searches: ["upwork|vendor onboarding"],
                  total_spent_min: 1,
                  hire_rate_min: 1,
                  min_money_gated_candidates: 1
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, agent_frame)

            {:reply, before_resp, _} = GetFrame.execute(%{frame_id: frame_id}, agent_frame)
            pjs_before = pjs_count(decode_payload(before_resp))

            %{frame_id: frame_id, pjs_before: pjs_before}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the founder tightens money_gate severely and re-Scores", context do
        {:reply, _, _} =
          UpdateFrame.execute(
            %{
              frame_id: context.frame_id,
              total_spent_min: 999_999,
              hire_rate_min: 99
            },
            context.agent_frame
          )

        {:reply, _, _} = RunScore.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:reply, after_resp, _} =
          GetFrame.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:ok, Map.put(context, :pjs_after, pjs_count(decode_payload(after_resp)))}
      end

      then_ "PaidJobSignal count is identical before and after the threshold change",
            context do
        assert context.pjs_after == context.pjs_before,
               "expected PJS count unchanged across threshold tightening; before=#{context.pjs_before}, after=#{context.pjs_after}"
        {:ok, context}
      end
    end
  end
end
