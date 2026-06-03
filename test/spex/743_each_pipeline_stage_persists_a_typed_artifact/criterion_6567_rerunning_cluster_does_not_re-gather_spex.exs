defmodule MarketMySpecSpex.Story743.Criterion6567Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6567 — Rerunning Cluster does not re-Gather.

  Cluster is independent of Gather. Calling RunCluster multiple times
  on the same Frame must not trigger any new Gather work — the
  JobPosting count stays constant, no corpus-source HTTP traffic
  results from re-clustering.

  Interaction surface: MCP tool execution (RunGather once, then
  RunCluster twice), observing that JobPosting counts are unchanged
  across the second RunCluster call.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame
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

  defp job_posting_count(payload) do
    artifacts = payload["artifacts"] || %{}
    artifacts["JobPosting"] || 0
  end

  spex "Rerunning Cluster does not trigger any new Gather work" do
    scenario "After Gather, two RunCluster invocations leave JobPosting count unchanged" do
      given_ "a Frame with Gather complete; JobPosting count recorded", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6567", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Rerunning Cluster",
                  saved_searches: ["upwork|vendor onboarding"],
                  total_spent_min: 1_000,
                  hire_rate_min: 30,
                  min_money_gated_candidates: 1
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)

            {:reply, after_gather, _} = GetFrame.execute(%{frame_id: frame_id}, agent_frame)
            jp_before = job_posting_count(decode_payload(after_gather))

            %{frame_id: frame_id, jp_before: jp_before}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent invokes RunCluster twice in a row", context do
        jp_after =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6567", fn ->
            {:reply, _, _} = RunCluster.execute(%{frame_id: context.frame_id}, context.agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: context.frame_id}, context.agent_frame)

            {:reply, after_cluster, _} =
              GetFrame.execute(%{frame_id: context.frame_id}, context.agent_frame)

            job_posting_count(decode_payload(after_cluster))
          end)

        {:ok, Map.put(context, :jp_after, jp_after)}
      end

      then_ "the JobPosting count is unchanged (Cluster did not re-Gather)", context do
        assert context.jp_after == context.jp_before,
               "expected JobPosting count to be unchanged by Cluster reruns; before: #{context.jp_before}, after: #{context.jp_after}"
        {:ok, context}
      end
    end
  end
end
