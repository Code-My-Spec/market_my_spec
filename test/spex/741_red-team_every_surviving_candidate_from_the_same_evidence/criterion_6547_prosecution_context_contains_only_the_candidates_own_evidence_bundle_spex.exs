defmodule MarketMySpecSpex.Story741.Criterion6547Spex do
  @moduledoc """
  Story 741 — Red-team every surviving candidate from the same evidence
  Criterion 6547 — Prosecution context contains only the Candidate's own evidence bundle.

  When the agent invokes RedTeamCandidate against Candidate X, the
  context handed to the prosecution must contain ONLY X's evidence —
  X's member JobPostings and X's gated_in PaidJobSignals. No cross-
  contamination from other Candidates' postings, no Frame-wide bag of
  results. The prosecution is per-Candidate-evidence per the Klein
  pre-mortem framing (only argue from the evidence that promoted *this*
  Candidate).

  Interaction surface: ListCandidates and verifying its per-Candidate
  evidence partitioning.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
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

  spex "Prosecution evidence bundle for a Candidate contains no foreign records" do
    scenario "ListCandidates returns per-Candidate evidence with no JobPosting shared across Candidates" do
      given_ "a Frame whose pipeline has produced multiple Candidates with disjoint JobPosting membership",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6547_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Prosecution evidence disjointness",
                  saved_searches: [
                    "upwork|vendor onboarding migration",
                    "upwork|supplier portal consolidation"
                  ],
                  total_spent_min: 1_000,
                  hire_rate_min: 30,
                  min_money_gated_candidates: 2
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, agent_frame)

            %{frame_id: frame_id}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent calls ListCandidates", context do
        {:reply, list_resp, _} =
          ListCandidates.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:ok, Map.put(context, :candidates, decode_payload(list_resp)["candidates"] || [])}
      end

      then_ "no JobPosting id appears in more than one Candidate's evidence bundle",
            context do
        all_jp_ids =
          context.candidates
          |> Enum.flat_map(fn c -> c["job_posting_ids"] || [] end)

        unique = Enum.uniq(all_jp_ids)

        assert length(all_jp_ids) == length(unique),
               "expected disjoint JobPosting membership across Candidates; got duplicates: #{inspect(all_jp_ids -- unique)}"

        {:ok, context}
      end

      then_ "each Candidate's evidence bundle is non-empty (the prosecution has something to argue from)",
            context do
        for c <- context.candidates do
          jp_ids = c["job_posting_ids"] || []

          assert jp_ids != [],
                 "expected each Candidate to carry at least one JobPosting in its prosecution evidence; Candidate #{inspect(c["id"])} has none"
        end

        {:ok, context}
      end
    end
  end
end
