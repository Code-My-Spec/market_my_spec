defmodule MarketMySpecSpex.Story741.Criterion6550Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6550 — Each Board row exposes the prosecution residue alongside
  the verdict.

  When the founder looks at a Board row, they must see not just the
  verdict but the prosecution residue: kill_argument and
  cheapest_kill_test. The Board format does not bury or summarize the
  kill argument — the prosecution residue rides alongside the verdict at
  equal prominence (per Klein/Munger; the kill argument is what makes
  the verdict trustworthy).

  Interaction surface: MCP tool execution (GetBoard); each row in the
  payload carries kill_argument + cheapest_kill_test fields when a
  RedTeamVerdict exists.
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

  spex "Each Board row exposes kill_argument + cheapest_kill_test alongside the verdict" do
    scenario "After Red-teaming all survivors, every Board row carries its prosecution residue" do
      given_ "a Frame whose pipeline has run end-to-end and every survivor has been Red-teamed",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6550_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Prosecution residue on Board",
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

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: frame_id}, agent_frame)

            survivors =
              decode_payload(list_resp)["candidates"]
              |> Enum.filter(fn c -> (c["score"] || 0) >= 1 end)

            for s <- survivors do
              {:reply, _, _} =
                RedTeamCandidate.execute(
                  %{
                    candidate_id: s["id"],
                    verdict: "keep_productizable",
                    kill_argument: "Specific damaging argument for Candidate #{s["id"]}.",
                    cheapest_kill_test: "Specific cheapest test for Candidate #{s["id"]}."
                  },
                  agent_frame
                )
            end

            %{frame_id: frame_id}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent fetches the Board", context do
        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:ok, Map.put(context, :board, decode_payload(board_resp))}
      end

      then_ "every Board row carries a verdict, kill_argument, and cheapest_kill_test field",
            context do
        rendered = context.board["candidates"] || []

        assert rendered != [],
               "expected non-empty Board to verify prosecution residue against"

        for row <- rendered do
          assert is_binary(row["verdict"]) or is_atom(row["verdict"]),
                 "expected verdict on row #{inspect(row["id"])}; got: #{inspect(row["verdict"])}"

          assert is_binary(row["kill_argument"]),
                 "expected kill_argument on row #{inspect(row["id"])}; got: #{inspect(row["kill_argument"])}"

          assert is_binary(row["cheapest_kill_test"]),
                 "expected cheapest_kill_test on row #{inspect(row["id"])}; got: #{inspect(row["cheapest_kill_test"])}"

          assert byte_size(row["kill_argument"]) > 0,
                 "expected non-empty kill_argument on row #{inspect(row["id"])}"

          assert byte_size(row["cheapest_kill_test"]) > 0,
                 "expected non-empty cheapest_kill_test on row #{inspect(row["id"])}"
        end

        {:ok, context}
      end
    end
  end
end
