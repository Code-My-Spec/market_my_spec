defmodule MarketMySpecSpex.Story740.Criterion6540Spex do
  @moduledoc """
  Story 740 — Pluggable data sources behind a fixed validation contract
  Criterion 6540 — PaidJobSignal's job_posting association returns exactly one record.

  Each PaidJobSignal belongs to exactly one JobPosting (the one Score
  evaluated). The has_one / belongs_to shape must be enforced; loading
  a PaidJobSignal's job_posting association returns a single
  %JobPosting{} struct, not a list, not nil.

  Interaction surface: LiveView assigns inspection. The Frame detail
  LiveView preloads associations; we observe the typed structure there.
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

  spex "Each PaidJobSignal's job_posting association returns exactly one JobPosting" do
    scenario "Loading a PaidJobSignal via the Frame's Board view returns a single %JobPosting{} struct, not a list" do
      given_ "a Frame whose full pipeline through Score has run", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6540_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "PaidJobSignal-to-JobPosting cardinality",
                  saved_searches: ["upwork|vendor onboarding"],
                  total_spent_min: 1,
                  hire_rate_min: 1,
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
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, Map.merge(context, Map.put(result, :authed_conn, authed_conn))}
      end

      when_ "the founder mounts the Frame detail LiveView", context do
        {:ok, view, _} =
          live(context.authed_conn, "/app/problem-discovery/frames/#{context.frame_id}")

        board = :sys.get_state(view.pid).socket.assigns[:board]
        {:ok, Map.put(context, :board, board)}
      end

      then_ "every PaidJobSignal in the Board's preloaded candidates carries exactly one job_posting",
            context do
        candidates = context.board.candidates || []

        signals =
          Enum.flat_map(candidates, fn c -> c.paid_job_signals || [] end)

        assert signals != [],
               "expected at least one PaidJobSignal on the Board to verify cardinality against"

        for signal <- signals do
          jp = signal.job_posting

          refute is_list(jp),
                 "expected PaidJobSignal.job_posting to be a single struct; got list: #{inspect(jp)}"

          refute is_nil(jp),
                 "expected PaidJobSignal.job_posting to be loaded; got nil"

          assert is_struct(jp, MarketMySpec.ProblemDiscovery.JobPosting),
                 "expected %JobPosting{} struct; got: #{inspect(jp)}"
        end

        {:ok, context}
      end
    end
  end
end
