defmodule MarketMySpecSpex.Story741.Criterion6546Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6546 — Every Score-survivor gets a RedTeamVerdict before the Board renders.

  A "Score-survivor" is a Candidate whose `score >= 1` (at least one
  gated_in PaidJobSignal). Before the Board can render any rows, every
  such Candidate must carry a RedTeamVerdict — no row should appear on
  the Board lacking a prosecuted verdict.

  Interaction surface: MCP tool execution (GetBoard) on a Frame whose
  Score has run but Red-team has been skipped for some survivors.
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

  spex "Every Score-survivor must have a RedTeamVerdict before the Board renders it" do
    scenario "Board does not render Candidates that survived Score without a RedTeamVerdict" do
      given_ "a Frame whose Score has produced N survivors, none yet Red-teamed", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6546_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Survivor must be Red-teamed",
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

            survivors =
              decode_payload(list_resp)["candidates"]
              |> Enum.filter(fn c -> (c["score"] || 0) >= 1 end)

            %{frame_id: frame_id, survivors: survivors}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent fetches the Board without having Red-teamed any survivor", context do
        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:ok, Map.put(context, :board, decode_payload(board_resp))}
      end

      then_ "the Board contains zero rows (no survivor without a RedTeamVerdict appears)",
            context do
        rendered = context.board["candidates"] || []

        assert rendered == [],
               "expected zero Board rows when no Red-team has run; got #{length(rendered)} rendered"
        {:ok, context}
      end

      then_ "after Red-teaming every survivor, the Board renders each of them", context do
        for survivor <- context.survivors do
          {:reply, _, _} =
            RedTeamCandidate.execute(
              %{
                candidate_id: survivor["id"],
                verdict: "keep_productizable",
                kill_argument: "Prosecution argument from survivor evidence.",
                cheapest_kill_test: "One client call."
              },
              context.agent_frame
            )
        end

        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.agent_frame)

        rendered = decode_payload(board_resp)["candidates"] || []

        assert length(rendered) == length(context.survivors),
               "expected every Red-teamed survivor on the Board; got #{length(rendered)} / #{length(context.survivors)}"
        {:ok, context}
      end
    end
  end
end
