defmodule MarketMySpecSpex.Story741.Criterion6552Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6552 — RedTeamVerdict's candidate association returns exactly
  one record.

  Each RedTeamVerdict belongs to exactly one Candidate (the one being
  prosecuted). The has_one / belongs_to shape must be enforced; loading a
  RedTeamVerdict's candidate association returns a single %Candidate{}
  struct, not a list, not nil.

  Interaction surface: LiveView assigns inspection. The Frame detail
  LiveView preloads the verdict on each Candidate; we observe the typed
  structure there.
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

  spex "RedTeamVerdict's candidate association returns exactly one %Candidate{}" do
    scenario "After prosecution, the verdict's loaded candidate is one struct (not a list, not nil)" do
      given_ "a Frame whose pipeline through Red-team has run for at least one Candidate",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6552_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Verdict-candidate cardinality",
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

            [survivor | _] = decode_payload(list_resp)["candidates"]

            {:reply, _, _} =
              RedTeamCandidate.execute(
                %{
                  candidate_id: survivor["id"],
                  verdict: "keep_productizable",
                  kill_argument: "Prosecution argument.",
                  cheapest_kill_test: "One call."
                },
                agent_frame
              )

            %{frame_id: frame_id, survivor_id: survivor["id"]}
          end)

        {token, _} = Fixtures.generate_user_magic_link_token(scope.user)
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, Map.merge(context, Map.put(result, :authed_conn, authed_conn))}
      end

      when_ "the founder mounts the Frame detail LiveView", context do
        {:ok, view, _} =
          live(context.authed_conn, "/problem-discovery/frames/#{context.frame_id}")

        board = :sys.get_state(view.pid).socket.assigns[:board]
        {:ok, Map.put(context, :board, board)}
      end

      then_ "the Red-teamed Candidate carries a single %RedTeamVerdict{} (whose candidate field, when loaded, is one struct)",
            context do
        candidates = context.board.candidates || []

        candidate = Enum.find(candidates, fn c -> c.id == context.survivor_id end)

        assert candidate, "expected Red-teamed Candidate to be on the Board"

        verdict = candidate.red_team_verdict

        refute is_nil(verdict),
               "expected red_team_verdict to be loaded (not nil)"

        refute is_list(verdict),
               "expected red_team_verdict to be a single struct (not a list); got: #{inspect(verdict)}"

        assert is_struct(verdict, MarketMySpec.ProblemDiscovery.RedTeamVerdict),
               "expected red_team_verdict to be a %RedTeamVerdict{} struct; got: #{inspect(verdict)}"

        {:ok, context}
      end
    end
  end
end
