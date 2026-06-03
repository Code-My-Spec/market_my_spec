defmodule MarketMySpecSpex.Story741.Criterion6553Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6553 — Candidate without a RedTeamVerdict is excluded from the
  Board with an integrity diagnostic.

  A Score-survivor without a RedTeamVerdict cannot appear on the Board
  (criterion 6546). When it's excluded, the Board exposes an integrity
  diagnostic — a count or list of survivors awaiting prosecution — so
  the founder/agent knows there's outstanding work before the Board is
  trustworthy.

  Interaction surface: MCP tool execution (GetBoard) on a Frame in a
  mid-prosecution state.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetBoard
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
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

  spex "Candidates awaiting Red-team are excluded but surfaced as an integrity diagnostic" do
    scenario "The Board reports an awaiting_redteam count or list when Red-team has not run for all survivors" do
      given_ "a Frame whose Score has produced N survivors, none Red-teamed yet", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6553_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Awaiting Red-team integrity diagnostic",
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

            assert survivors != [],
                   "test precondition: at least one survivor is needed to verify the awaiting-Red-team diagnostic"

            %{frame_id: frame_id, survivor_count: length(survivors)}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent fetches the Board", context do
        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:ok, Map.put(context, :board, decode_payload(board_resp))}
      end

      then_ "the Board surfaces an integrity diagnostic naming the awaiting-Red-team survivor count",
            context do
        diagnostic =
          context.board["awaiting_redteam"] ||
            context.board[:awaiting_redteam] ||
            context.board["integrity"] ||
            context.board[:integrity]

        assert diagnostic,
               "expected the Board to expose an 'awaiting_redteam' or 'integrity' diagnostic field; got board: #{inspect(context.board)}"

        cond do
          is_integer(diagnostic) ->
            assert diagnostic == context.survivor_count,
                   "expected awaiting_redteam count to equal survivor count (#{context.survivor_count}); got: #{diagnostic}"

          is_list(diagnostic) ->
            assert length(diagnostic) == context.survivor_count,
                   "expected awaiting_redteam list length to equal survivor count (#{context.survivor_count}); got: #{length(diagnostic)}"

          is_map(diagnostic) ->
            count = diagnostic["count"] || diagnostic[:count] || length(diagnostic["ids"] || [])

            assert count == context.survivor_count,
                   "expected awaiting_redteam.count to equal survivor count (#{context.survivor_count}); got: #{count}"

          true ->
            flunk("unexpected diagnostic shape: #{inspect(diagnostic)}")
        end

        {:ok, context}
      end

      then_ "the Board's rendered candidates list excludes the awaiting-Red-team survivors",
            context do
        rendered = context.board["candidates"] || []

        assert rendered == [],
               "expected zero rendered candidates when no Red-team has run; got #{length(rendered)} rendered"
        {:ok, context}
      end
    end
  end
end
