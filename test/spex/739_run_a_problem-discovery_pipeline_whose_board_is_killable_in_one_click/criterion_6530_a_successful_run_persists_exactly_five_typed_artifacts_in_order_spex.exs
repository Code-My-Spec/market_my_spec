defmodule MarketMySpecSpex.Story739.Criterion6530Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6530 — A successful run persists exactly five typed artifacts in order.

  A complete pipeline run for a Frame produces persisted records of exactly
  five typed artifact kinds, created in pipeline order:
  JobPosting → Candidate → PaidJobSignal → RedTeamVerdict → Board.

  The Frame itself is the founder's input (pre-pipeline) and the Board is
  the projection (assembled view). The five stage artifacts are
  observable through MCP introspection of the Frame's artifact graph.

  Interaction surface: MCP tool execution (GetFrame returns per-stage
  artifact counts and creation timestamps so the agent can verify
  presence and ordering).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RedTeamCandidate
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore
  alias MarketMySpecSpex.Fixtures
  alias MarketMySpecSpex.ProblemDiscoveryHelpers

  @expected_artifact_kinds ~w(JobPosting Candidate PaidJobSignal RedTeamVerdict Board)

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

  spex "A successful run persists exactly five typed artifacts in pipeline order" do
    scenario "Complete pipeline produces JobPosting → Candidate → PaidJobSignal → RedTeamVerdict → Board" do
      given_ "a Frame has been committed", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        {:reply, create_resp, _} =
          CreateFrame.execute(
            %{
              description: "Five-artifact pipeline run",
              saved_searches: ["upwork|vendor onboarding"],
              total_spent_min: 1,
              hire_rate_min: 1,
              min_money_gated_candidates: 1
            },
            frame
          )

        frame_id = decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

        {:ok, Map.merge(context, %{frame: frame, frame_id: frame_id})}
      end

      when_ "the agent runs all five pipeline stages end-to-end", context do
        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6530_when", fn ->
            {:reply, _, _} = RunGather.execute(%{frame_id: context.frame_id}, context.frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: context.frame_id}, context.frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: context.frame_id}, context.frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: context.frame_id}, context.frame)

            survivors =
              decode_payload(list_resp)["candidates"]
              |> Enum.filter(fn c -> (c["score"] || 0) > 0 end)

            verdicts = ~w(keep_productizable keep_service_only watch kill)

            for {candidate, i} <- Enum.with_index(survivors) do
              {:reply, _, _} =
                RedTeamCandidate.execute(
                  %{
                    candidate_id: candidate["id"],
                    verdict: Enum.at(verdicts, rem(i, length(verdicts))),
                    kill_argument: "Prosecution argument #{i}.",
                    cheapest_kill_test: "Cheapest test #{i}."
                  },
                  context.frame
                )
            end

            {:reply, frame_resp, _} =
              GetFrame.execute(%{frame_id: context.frame_id}, context.frame)

            %{frame_state: decode_payload(frame_resp)}
          end)

        {:ok, Map.merge(context, result)}
      end

      then_ "the Frame's artifact graph reports nonzero counts for exactly the five expected artifact kinds",
            context do
        artifacts = context.frame_state["artifacts"] || context.frame_state[:artifacts] || %{}

        kinds_present =
          artifacts
          |> Map.to_list()
          |> Enum.filter(fn {_kind, count} -> is_integer(count) and count > 0 end)
          |> Enum.map(fn {kind, _} -> to_string(kind) end)
          |> Enum.sort()

        assert kinds_present == Enum.sort(@expected_artifact_kinds),
               "expected exactly these artifact kinds with nonzero counts: #{inspect(@expected_artifact_kinds)}; got: #{inspect(kinds_present)}"

        {:ok, context}
      end

      then_ "the Frame's artifact graph reports creation ordering matching pipeline order",
            context do
        ordering = context.frame_state["artifact_creation_order"] ||
                     context.frame_state[:artifact_creation_order] || []

        ordering_strings = Enum.map(ordering, &to_string/1)

        assert ordering_strings == @expected_artifact_kinds,
               "expected artifact creation order to be #{inspect(@expected_artifact_kinds)}; got: #{inspect(ordering_strings)}"

        {:ok, context}
      end
    end
  end
end
