defmodule MarketMySpecSpex.Story743.Criterion6569Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6569 — Sam walks a Board verdict back to its source JobPostings.

  Provenance: every Board row (a Candidate with verdict) must be walkable
  back through its Candidate → member JobPostings. From a Board row's
  id, the agent can fetch the Candidate and its job_posting_ids; from
  those, the source JobPosting records (with their URLs to the source
  platform).

  Interaction surface: MCP tool execution (GetBoard → ListCandidates).
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

  spex "A Board verdict walks back to source JobPostings" do
    scenario "From a Board row, follow Candidate → job_posting_ids → JobPosting records" do
      given_ "a Frame whose pipeline is end-to-end including Red-team for at least one Candidate",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        frame_id =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6569", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Provenance walkback",
                  saved_searches: [%{source: "upwork", query: "vendor onboarding"}],
                  money_gate: %{total_spent_min: 1, hire_rate_min: 1},
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

            [survivor | _] =
              decode_payload(list_resp)["candidates"]
              |> Enum.filter(fn c -> (c["score"] || 0) >= 1 end)

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

            frame_id
          end)

        {:ok, Map.merge(context, %{agent_frame: agent_frame, frame_id: frame_id})}
      end

      when_ "the agent fetches the Board and walks back via ListCandidates", context do
        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.agent_frame)

        [row | _] = decode_payload(board_resp)["candidates"]

        {:reply, list_resp, _} =
          ListCandidates.execute(%{frame_id: context.frame_id}, context.agent_frame)

        candidates = decode_payload(list_resp)["candidates"] || []
        candidate = Enum.find(candidates, fn c -> c["id"] == row["id"] end)

        {:ok, Map.merge(context, %{row: row, candidate: candidate})}
      end

      then_ "the Candidate carries a non-empty list of source JobPosting ids", context do
        assert context.candidate,
               "expected to find the Board row's Candidate via ListCandidates"

        jp_ids = context.candidate["job_posting_ids"] || []

        assert jp_ids != [],
               "expected the Candidate to carry source JobPosting ids for provenance walkback; got empty list"
        {:ok, context}
      end

      then_ "the Board row exposes openable verification_links from the source JobPostings",
            context do
        links = context.row["verification_links"] || []

        assert Enum.any?(links, fn url ->
                 is_binary(url) and
                   (String.starts_with?(url, "http://") or String.starts_with?(url, "https://"))
               end),
               "expected Board row to expose openable verification_links from source JobPostings; got: #{inspect(links)}"
        {:ok, context}
      end
    end
  end
end
