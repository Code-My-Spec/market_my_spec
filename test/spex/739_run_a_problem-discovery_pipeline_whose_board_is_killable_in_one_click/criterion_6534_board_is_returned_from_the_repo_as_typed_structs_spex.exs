defmodule MarketMySpecSpex.Story739.Criterion6534Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6534 — Board is returned from the Repo as typed structs.

  The Board is a DB-backed projection over the typed artifacts (Frame,
  JobPosting, Candidate, PaidJobSignal, RedTeamVerdict). When the Board
  is rendered to the LiveView (or returned by the GetBoard MCP tool), the
  underlying rows must be typed Ecto structs (%Candidate{},
  %RedTeamVerdict{}, etc.), not raw maps from a Repo.all/1 over a custom
  SELECT.

  This rule ensures downstream consumers (the LiveView, the MCP tool,
  external code) can pattern-match on struct types and rely on the
  schema's typed fields rather than parsing dynamic maps.

  Interaction surface: LiveView mount — assert the rendered assigns
  carry typed structs for the Board rows. The agent's `GetBoard` payload
  is JSON (encoded from those structs), so the in-process LiveView assigns
  are where the struct typing is observable.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
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

  spex "Board rows are typed Ecto structs on the LiveView assigns" do
    scenario "Frame detail LiveView mounts with Board assigns carrying %Candidate{} and %RedTeamVerdict{} structs" do
      given_ "a Frame whose pipeline has run end-to-end with at least one verdicted Candidate",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6534_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Typed-struct Board",
                  saved_searches: [%{source: "upwork", query: "vendor onboarding"}],
                  money_gate: %{total_spent_min: 1, hire_rate_min: 1},
                  kill_condition: %{min_money_gated_candidates: 1}
                },
                agent_frame
              )

            frame_id =
              decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, agent_frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: frame_id}, agent_frame)

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
                  agent_frame
                )
            end

            %{frame_id: frame_id}
          end)

        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)

        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, Map.merge(context, Map.put(result, :authed_conn, authed_conn))}
      end

      when_ "the founder mounts the Frame detail LiveView", context do
        {:ok, view, _html} =
          live(context.authed_conn, "/problem-discovery/frames/#{context.frame_id}")

        board_assign = :sys.get_state(view.pid).socket.assigns[:board]

        {:ok, Map.put(context, :board_assign, board_assign)}
      end

      then_ "the Board's candidates are %Candidate{} structs, not raw maps", context do
        candidates = context.board_assign.candidates || context.board_assign[:candidates]

        assert is_list(candidates) and candidates != [],
               "expected non-empty candidates list on Board assigns; got: #{inspect(candidates)}"

        for cand <- candidates do
          assert is_struct(cand, MarketMySpec.ProblemDiscovery.Candidate),
                 "expected candidate to be a %MarketMySpec.ProblemDiscovery.Candidate{}; got: #{inspect(cand)}"
        end

        {:ok, context}
      end

      then_ "each candidate's red_team_verdict is a %RedTeamVerdict{} struct", context do
        candidates = context.board_assign.candidates || context.board_assign[:candidates]

        for cand <- candidates do
          verdict_struct = cand.red_team_verdict || cand[:red_team_verdict]

          if verdict_struct do
            assert is_struct(verdict_struct, MarketMySpec.ProblemDiscovery.RedTeamVerdict),
                   "expected red_team_verdict to be a %MarketMySpec.ProblemDiscovery.RedTeamVerdict{} struct; got: #{inspect(verdict_struct)}"
          end
        end

        {:ok, context}
      end
    end
  end
end
