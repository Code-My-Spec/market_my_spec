defmodule MarketMySpecSpex.Story741.Criterion6555Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6555 — Red-team flip from KEEP to KILL overwrites Score's verdict
  on the Board.

  A Candidate that Score classified as a survivor (gated_in count ≥
  threshold) but Red-team prosecutes as KILL must show as KILL on the
  Board — not as KEEP. The RedTeamVerdict overwrites Score's mechanical
  verdict at render time (per Three Amigos rule "Red team overwrites").

  Interaction surface: MCP tool execution (RunScore → RedTeamCandidate
  with KILL → GetBoard). The Board's row for the candidate must reflect
  the KILL verdict.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetBoard
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

  spex "Red-team's KILL verdict overwrites Score's KEEP on the Board" do
    scenario "Survivor with score >= 1 that's Red-teamed as KILL shows verdict=kill on the Board" do
      given_ "a Frame whose Score produced a Candidate that would render as KEEP from mechanical scoring alone",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6555_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Red-team KILL overwrites Score KEEP",
                  saved_searches: ["upwork|vendor onboarding"],
                  total_spent_min: 1_000,
                  hire_rate_min: 30,
                  min_money_gated_candidates: 1
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, agent_frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: frame_id}, agent_frame)

            [survivor | _] =
              decode_payload(list_resp)["candidates"]
              |> Enum.filter(fn c -> (c["score"] || 0) >= 1 end)

            %{frame_id: frame_id, survivor_id: survivor["id"]}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent Red-teams that survivor with verdict=kill", context do
        {:reply, _, _} =
          RedTeamCandidate.execute(
            %{
              candidate_id: context.survivor_id,
              verdict: "kill",
              kill_argument: "Looking back, the top 3 spenders all hired in Q1 2024 and never returned — the demand was a trend already over.",
              cheapest_kill_test: "Re-check whether those clients posted again in the last 90 days."
            },
            context.agent_frame
          )

        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:ok, Map.put(context, :board, decode_payload(board_resp))}
      end

      then_ "the Board shows the survivor with verdict=kill (Red-team's verdict, not Score's)",
            context do
        rendered = context.board["candidates"] || []

        row = Enum.find(rendered, fn c -> c["id"] == context.survivor_id end)

        assert row,
               "expected the Red-teamed survivor on the Board; got rows: #{inspect(rendered)}"

        verdict_string =
          case row["verdict"] do
            v when is_binary(v) -> v
            v when is_atom(v) -> Atom.to_string(v)
            other -> other
          end

        assert verdict_string == "kill",
               "expected the Board's verdict for the survivor to be 'kill' (Red-team overwrites Score); got: #{inspect(verdict_string)}"
        {:ok, context}
      end
    end
  end
end
