defmodule MarketMySpecSpex.Story743.Criterion6574Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6574 — Rerunning Cluster three times leaves only one Candidate set.

  Overwrite semantics: each Cluster rerun replaces the previous Candidate
  set. After three RunCluster invocations, the database holds only the
  Candidates from the most recent run — not 3× the count.

  Interaction surface: MCP tool execution; ListCandidates count remains
  bounded across reruns.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
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

  spex "Rerunning Cluster three times leaves only the most-recent Candidate set" do
    scenario "After three RunCluster invocations, Candidate count equals the most-recent run's count (not 3×)" do
      given_ "a Frame with Gather complete and a baseline Cluster set established", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6574", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Cluster overwrite",
                  saved_searches: [%{source: "upwork", query: "vendor onboarding"}],
                  money_gate: %{total_spent_min: 1_000, hire_rate_min: 30},
                  kill_condition: %{min_money_gated_candidates: 1}
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: frame_id}, agent_frame)

            baseline_count = length(decode_payload(list_resp)["candidates"] || [])

            %{frame_id: frame_id, baseline_count: baseline_count}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent invokes RunCluster two more times", context do
        final_count =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6574", fn ->
            {:reply, _, _} =
              RunCluster.execute(%{frame_id: context.frame_id}, context.agent_frame)

            {:reply, _, _} =
              RunCluster.execute(%{frame_id: context.frame_id}, context.agent_frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: context.frame_id}, context.agent_frame)

            length(decode_payload(list_resp)["candidates"] || [])
          end)

        {:ok, Map.put(context, :final_count, final_count)}
      end

      then_ "Candidate count is unchanged across reruns (overwrite, not append)", context do
        # Cluster is overwrite-semantics: each rerun replaces the prior
        # Candidate set. Same input → same fingerprint → same cached
        # clustering result via Clustering.Recorder, so baseline and
        # final counts must match exactly.
        assert context.final_count == context.baseline_count,
               "expected Candidate count unchanged after 3 RunCluster invocations (overwrite); baseline=#{context.baseline_count}, final=#{context.final_count}"

        refute context.final_count >= 3 * context.baseline_count,
               "expected count NOT to accumulate (3 reruns × baseline); got #{context.final_count}"
        {:ok, context}
      end
    end
  end
end
