defmodule MarketMySpecSpex.Story743.Criterion6571Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6571 — Same PaidJobSignal record's classification flips when
  threshold moves.

  When the founder updates the money_gate threshold and re-runs Score,
  the PaidJobSignal record IDs remain the same — the records are
  updated in place, and only their classification field changes. No
  delete+create cycle.

  Interaction surface: pre/post Score classification observation against
  the same PaidJobSignal IDs through ListCandidates + paid_job_signals
  preload.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.UpdateFrame
  alias MarketMySpec.ProblemDiscovery.PaidJobSignal
  alias MarketMySpec.Repo
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

  spex "PaidJobSignal IDs persist across threshold changes; only classification flips" do
    scenario "Tightening money_gate keeps the same PaidJobSignal IDs but flips their classification" do
      given_ "a Frame whose pipeline has produced PaidJobSignals under a lenient money_gate",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6571", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "ID stability across threshold change",
                  saved_searches: [%{source: "upwork", query: "vendor onboarding"}],
                  money_gate: %{total_spent_min: 100, hire_rate_min: 10},
                  kill_condition: %{min_money_gated_candidates: 1}
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, agent_frame)

            ids_before = Repo.all(PaidJobSignal) |> Enum.map(& &1.id) |> MapSet.new()

            %{frame_id: frame_id, ids_before: ids_before}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the founder tightens money_gate to $100,000/95% and re-runs Score", context do
        {:reply, _, _} =
          UpdateFrame.execute(
            %{
              frame_id: context.frame_id,
              money_gate: %{total_spent_min: 100_000, hire_rate_min: 95}
            },
            context.agent_frame
          )

        {:reply, _, _} = RunScore.execute(%{frame_id: context.frame_id}, context.agent_frame)

        ids_after = Repo.all(PaidJobSignal) |> Enum.map(& &1.id) |> MapSet.new()

        {:ok, Map.put(context, :ids_after, ids_after)}
      end

      then_ "the set of PaidJobSignal IDs is identical before and after the threshold change",
            context do
        assert MapSet.equal?(context.ids_before, context.ids_after),
               "expected PaidJobSignal IDs to persist across threshold change (in-place update); before=#{inspect(MapSet.to_list(context.ids_before))}, after=#{inspect(MapSet.to_list(context.ids_after))}"
        {:ok, context}
      end
    end
  end
end
