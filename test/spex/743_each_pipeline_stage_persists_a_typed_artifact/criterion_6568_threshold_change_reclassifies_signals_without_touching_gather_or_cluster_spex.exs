defmodule MarketMySpecSpex.Story743.Criterion6568Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6568 — Threshold change reclassifies signals without touching
  Gather or Cluster.

  When the founder updates the Frame's money_gate threshold and re-runs
  Score, the underlying JobPosting count and Candidate count must be
  unchanged — Score reclassifies PaidJobSignal records in place, and
  Gather + Cluster artifacts are untouched.

  Interaction surface: MCP tool execution, comparing JobPosting and
  Candidate counts before and after the threshold change.
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

  defp counts(payload) do
    %{
      jp: payload["artifacts"]["JobPosting"] || 0,
      cand: payload["artifacts"]["Candidate"] || 0,
      pjs: payload["artifacts"]["PaidJobSignal"] || 0
    }
  end

  spex "Threshold change reclassifies PaidJobSignals without touching JobPostings or Candidates" do
    scenario "Update money_gate then re-Score; JP + Candidate + PJS counts are unchanged" do
      given_ "a Frame whose pipeline has run through Score with money_gate=$1,000/30%",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6568", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Threshold-change reclassification",
                  saved_searches: [%{source: "upwork", query: "vendor onboarding"}],
                  money_gate: %{total_spent_min: 1_000, hire_rate_min: 30},
                  kill_condition: %{min_money_gated_candidates: 1}
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, agent_frame)

            {:reply, before, _} = GetFrame.execute(%{frame_id: frame_id}, agent_frame)
            before_counts = counts(decode_payload(before))

            %{frame_id: frame_id, before_counts: before_counts}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the founder tightens money_gate to $10,000/70% and re-runs Score", context do
        {:reply, _, _} =
          UpdateFrame.execute(
            %{
              frame_id: context.frame_id,
              money_gate: %{total_spent_min: 10_000, hire_rate_min: 70}
            },
            context.agent_frame
          )

        {:reply, _, _} = RunScore.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:reply, after_resp, _} =
          GetFrame.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:ok, Map.put(context, :after_counts, counts(decode_payload(after_resp)))}
      end

      then_ "JobPosting count, Candidate count, and PaidJobSignal count are all unchanged",
            context do
        assert context.after_counts.jp == context.before_counts.jp,
               "JobPosting count changed: before=#{context.before_counts.jp}, after=#{context.after_counts.jp}"

        assert context.after_counts.cand == context.before_counts.cand,
               "Candidate count changed: before=#{context.before_counts.cand}, after=#{context.after_counts.cand}"

        assert context.after_counts.pjs == context.before_counts.pjs,
               "PaidJobSignal count changed: before=#{context.before_counts.pjs}, after=#{context.after_counts.pjs} (Score should reclassify in place, not delete+create)"
        {:ok, context}
      end
    end
  end
end
