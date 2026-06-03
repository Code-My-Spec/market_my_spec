defmodule MarketMySpecSpex.Story739.Criterion6525Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6525 — Every row on a completed run carries one of the four canonical verdicts
  (KEEP-PRODUCTIZABLE, KEEP-SERVICE-ONLY, WATCH, KILL).

  After a full pipeline run (Gather → Cluster → Score → Red-team), the Board
  must expose every Candidate row with a verdict drawn from the canonical
  four-verdict enum. No "unknown", no nil, no other values.

  Interaction surface: MCP tool execution (agent reads the Board via GetBoard).
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

  @canonical_verdicts ~w(keep_productizable keep_service_only watch kill)

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

  spex "Board exposes every Candidate with one of the four canonical verdicts" do
    scenario "Full pipeline run produces a Board whose rows all carry a canonical verdict" do
      given_ "a Frame has been committed for an account-scoped session", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        {:reply, create_resp, _} =
          CreateFrame.execute(
            %{
              description: "Vendor onboarding pain — agencies migrating sub-accounts",
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

      when_ "the agent runs the full pipeline and fetches the Board", context do
        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6525_when", fn ->
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

            {:reply, board_resp, _} =
              GetBoard.execute(%{frame_id: context.frame_id}, context.frame)

            %{board: decode_payload(board_resp)}
          end)

        {:ok, Map.merge(context, result)}
      end

      then_ "every row on the Board carries a verdict from the canonical four-verdict enum",
            context do
        candidates = context.board["candidates"] || context.board[:candidates] || []

        assert candidates != [],
               "expected a non-empty Board to validate verdicts against; got empty board"

        for row <- candidates do
          verdict = row["verdict"] || row[:verdict]

          assert is_binary(verdict) or is_atom(verdict),
                 "expected verdict to be a string or atom; got: #{inspect(verdict)}"

          verdict_string = if is_atom(verdict), do: Atom.to_string(verdict), else: verdict

          assert verdict_string in @canonical_verdicts,
                 "expected verdict in #{inspect(@canonical_verdicts)}; got: #{inspect(verdict)} on row #{inspect(row["label"] || row[:label])}"
        end

        {:ok, context}
      end
    end
  end
end
