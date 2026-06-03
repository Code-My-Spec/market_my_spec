defmodule MarketMySpecSpex.Story743.Criterion6565Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6565 — Cluster reads JobPostings from the database, not from
  in-process state.

  Gather and Cluster are independent operations. After Gather has run
  and persisted JobPostings, a fresh process invocation of Cluster
  (with no in-memory continuity to the Gather call) must still produce
  Candidates — meaning Cluster reads from the database, not from
  Gather's return value.

  Interaction surface: MCP tool execution with explicit separation
  between Gather and Cluster invocations.
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

  spex "Cluster reads JobPostings from the database after Gather has persisted them" do
    scenario "Gather + Cluster invoked from separate Task processes still produces Candidates" do
      given_ "a Frame committed and Gather having been run in a separate Task (no in-process continuity)",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        ProblemDiscoveryHelpers.with_problem_discovery_cassette(
          "criterion_6565",
          fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Cluster reads from DB",
                  saved_searches: [%{source: "upwork", query: "vendor onboarding"}],
                  money_gate: %{total_spent_min: 1_000, hire_rate_min: 30},
                  kill_condition: %{min_money_gated_candidates: 1}
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]
            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            Process.put(:frame_id, frame_id)
          end
        )

        {:ok, Map.merge(context, %{agent_frame: agent_frame, frame_id: Process.get(:frame_id)})}
      end

      when_ "the agent invokes RunCluster from a fresh Task with no in-process continuity",
            context do
        ProblemDiscoveryHelpers.with_problem_discovery_cassette(
          "criterion_6565",
          fn ->
            {:reply, _, _} =
              RunCluster.execute(%{frame_id: context.frame_id}, context.agent_frame)
          end
        )

        {:reply, list_resp, _} =
          ListCandidates.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:ok, Map.put(context, :candidates, decode_payload(list_resp)["candidates"] || [])}
      end

      then_ "Candidates exist (Cluster successfully read JobPostings from the database)",
            context do
        assert context.candidates != [],
               "expected Cluster to produce Candidates by reading the persisted JobPostings; got none"
        {:ok, context}
      end
    end
  end
end
