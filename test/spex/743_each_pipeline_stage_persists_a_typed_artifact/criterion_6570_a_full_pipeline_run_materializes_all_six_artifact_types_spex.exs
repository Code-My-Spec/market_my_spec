defmodule MarketMySpecSpex.Story743.Criterion6570Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6570 — A full pipeline run materializes all six artifact types.

  A pipeline run end-to-end produces records of all six artifact kinds:
  Frame, JobPosting, Candidate, PaidJobSignal, RedTeamVerdict, and Board
  (the latter as a projected view, not a schema; observable through
  GetBoard).

  Interaction surface: MCP tool execution; GetFrame returns the artifact
  counts, GetBoard confirms the Board projection exists.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetBoard
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RedTeamCandidate
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore
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

  spex "Full pipeline materializes all six artifact types" do
    scenario "End-to-end pipeline run produces Frame + JobPosting + Candidate + PaidJobSignal + RedTeamVerdict + Board" do
      given_ "an account-scoped agent frame", context do
        scope = Fixtures.account_scoped_user_fixture()
        {:ok, Map.put(context, :agent_frame, build_frame(scope))}
      end

      when_ "the agent runs every stage of the pipeline end-to-end", context do
        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6570", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Full pipeline run",
                  saved_searches: ["upwork|vendor onboarding"],
                  total_spent_min: 1_000,
                  hire_rate_min: 30,
                  min_money_gated_candidates: 1
                },
                context.agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, context.agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, context.agent_frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, context.agent_frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: frame_id}, context.agent_frame)

            [survivor | _] =
              decode_payload(list_resp)["candidates"]
              |> Enum.filter(fn c -> (c["score"] || 0) >= 1 end)

            {:reply, _, _} =
              RedTeamCandidate.execute(
                %{
                  candidate_id: survivor["id"],
                  verdict: "keep_productizable",
                  kill_argument: "Prosecution.",
                  cheapest_kill_test: "Call."
                },
                context.agent_frame
              )

            {:reply, frame_resp, _} =
              GetFrame.execute(%{frame_id: frame_id}, context.agent_frame)

            {:reply, board_resp, _} =
              GetBoard.execute(%{frame_id: frame_id}, context.agent_frame)

            %{
              frame_state: decode_payload(frame_resp),
              board_state: decode_payload(board_resp)
            }
          end)

        {:ok, Map.merge(context, result)}
      end

      then_ "each of the five artifact-schema types has at least one persisted record",
            context do
        artifacts = context.frame_state["artifacts"] || %{}

        for kind <- ~w(JobPosting Candidate PaidJobSignal RedTeamVerdict) do
          count = artifacts[kind] || 0

          assert count >= 1,
                 "expected at least one #{kind}; got: #{count} (artifacts: #{inspect(artifacts)})"
        end

        {:ok, context}
      end

      then_ "the Board projection is assembled and carries candidates", context do
        assert is_list(context.board_state["candidates"]),
               "expected Board projection to expose a candidates list; got: #{inspect(context.board_state)}"
        {:ok, context}
      end
    end
  end
end
