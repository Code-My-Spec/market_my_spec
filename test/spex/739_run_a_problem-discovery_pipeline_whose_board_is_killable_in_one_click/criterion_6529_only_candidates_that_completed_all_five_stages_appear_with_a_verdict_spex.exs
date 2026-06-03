defmodule MarketMySpecSpex.Story739.Criterion6529Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6529 — Only candidates that completed all five stages appear with a verdict.

  No partial-pipeline board synthesis: a Candidate must have traversed
  Gather → Cluster → Score → Red-team → Board before it gets a verdict.
  Candidates that exist only at the Cluster stage (Score not yet run) or
  that have a Score but no RedTeamVerdict do not appear with a verdict on
  the Board.

  Interaction surface: MCP tool execution. Two pipeline-run states: only
  through-Score, vs through-Red-team. Only the through-Red-team Candidates
  appear with verdicts.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetBoard
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

  spex "Board only carries verdicts for Candidates that completed all five stages" do
    scenario "Candidates missing Red-team do not appear with a verdict on the Board" do
      given_ "a Frame whose pipeline has run through Score but not through Red-team",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6529_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Score-only pipeline state",
                  saved_searches: [
                    %{source: "upwork", query: "vendor onboarding migration"},
                    %{source: "upwork", query: "supplier consolidation"},
                    %{source: "upwork", query: "intake workflow rebuild"}
                  ],
                  money_gate: %{total_spent_min: 5_000, hire_rate_min: 50},
                  kill_condition: %{min_money_gated_candidates: 3}
                },
                frame
              )

            frame_id =
              decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, frame)

            # NOTE: deliberately do NOT run Red-team — those Candidates remain
            # without a RedTeamVerdict, so they have not completed all five stages.

            %{frame: frame, frame_id: frame_id}
          end)

        {:ok, Map.merge(context, result)}
      end

      when_ "the agent fetches the Board", context do
        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.frame)

        {:ok, Map.put(context, :board, decode_payload(board_resp))}
      end

      then_ "no Candidate appears with a verdict — the Board surfaces no verdicted rows",
            context do
        candidates = context.board["candidates"] || context.board[:candidates] || []

        verdicted =
          Enum.filter(candidates, fn row ->
            v = row["verdict"] || row[:verdict]
            not is_nil(v) and v != ""
          end)

        assert verdicted == [],
               "expected zero verdicted rows on the Board (no Candidate has completed Red-team); got: #{inspect(verdicted)}"

        {:ok, context}
      end
    end
  end
end
