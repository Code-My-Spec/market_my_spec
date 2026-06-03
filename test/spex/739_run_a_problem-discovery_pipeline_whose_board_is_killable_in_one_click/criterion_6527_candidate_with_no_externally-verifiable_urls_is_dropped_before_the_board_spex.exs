defmodule MarketMySpecSpex.Story739.Criterion6527Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6527 — Candidate with no externally-verifiable URLs is dropped before the Board.

  Candidates whose constituent JobPostings carry no openable URLs cannot
  satisfy the evidence-link requirement (criterion 6526). The Board must
  drop them before assembly — they do not appear with any verdict.

  Interaction surface: MCP tool execution. A Candidate composed entirely of
  URL-less JobPostings does not surface on GetBoard's response.
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
  alias MarketMySpec.ProblemDiscovery.Candidate
  alias MarketMySpec.ProblemDiscovery.JobPosting
  alias MarketMySpec.ProblemDiscovery.PaidJobSignal
  alias MarketMySpec.ProblemDiscovery.RedTeamVerdict
  alias MarketMySpec.Repo
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

  defp insert_url_less_candidate!(frame_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, candidate} =
      Repo.insert(
        Candidate.changeset(%Candidate{}, %{
          frame_id: frame_id,
          centroid: Pgvector.new(List.duplicate(0.0, 1536)),
          score: 1,
          label: "URL-less synthetic candidate"
        })
      )

    {:ok, posting} =
      Repo.insert(
        JobPosting.changeset(%JobPosting{}, %{
          frame_id: frame_id,
          candidate_id: candidate.id,
          saved_search_index: 0,
          source: "upwork",
          source_id: "url-less-#{System.unique_integer([:positive])}",
          title: "URL-less synthetic posting",
          description: "Synthetic test fixture; no url field by design",
          url: nil,
          total_spent_cents: 1_000_000,
          hire_rate: 99,
          embedding: Pgvector.new(List.duplicate(0.0, 1536)),
          gathered_at: now
        })
      )

    {:ok, _signal} =
      Repo.insert(
        PaidJobSignal.changeset(%PaidJobSignal{}, %{
          job_posting_id: posting.id,
          candidate_id: candidate.id,
          classification: :gated_in
        })
      )

    {:ok, _verdict} =
      Repo.insert(
        RedTeamVerdict.changeset(%RedTeamVerdict{}, %{
          candidate_id: candidate.id,
          verdict: :keep_productizable,
          kill_argument: "Synthetic prosecution for the URL-less candidate.",
          cheapest_kill_test: "Synthetic kill test."
        })
      )

    candidate.id
  end

  spex "Candidates lacking openable verification URLs are dropped pre-Board" do
    scenario "A clustered Candidate whose JobPostings all lack URLs does not appear on the Board" do
      given_ "a Frame whose Gather produces at least one Candidate with no JobPosting URLs",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6527_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Mixed corpus including URL-less postings",
                  saved_searches: ["upwork|vendor onboarding"],
                  total_spent_min: 1,
                  hire_rate_min: 1,
                  min_money_gated_candidates: 1
                },
                frame
              )

            frame_id = decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, frame)
            {:reply, _, _} = RunScore.execute(%{frame_id: frame_id}, frame)

            # Red-team the real candidates so the Board has verdict'd rows
            # against which we can validate the URL-less drop rule.
            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: frame_id}, frame)

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
                  frame
                )
            end

            # Manufacture a URL-less Candidate: insert a Candidate +
            # JobPosting (url=nil) + PaidJobSignal so the Candidate has
            # score > 0 (would survive Score). Then assign it a verdict.
            # The Board MUST drop this row pre-assembly because the only
            # member posting has no openable URL.
            url_less_candidate_id = insert_url_less_candidate!(frame_id)

            %{
              frame: frame,
              frame_id: frame_id,
              url_less_candidate_id: url_less_candidate_id
            }
          end)

        {:ok, Map.merge(context, result)}
      end

      when_ "the agent fetches the Board", context do
        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.frame)

        {:ok, Map.put(context, :board, decode_payload(board_resp))}
      end

      then_ "the URL-less Candidate is not present on the Board with any verdict",
            context do
        candidates = context.board["candidates"] || context.board[:candidates] || []
        ids = Enum.map(candidates, fn row -> row["id"] || row[:id] end)

        refute context.url_less_candidate_id in ids,
               "expected URL-less Candidate #{inspect(context.url_less_candidate_id)} to be dropped before Board assembly; found it among Board candidate ids: #{inspect(ids)}"

        {:ok, context}
      end
    end
  end
end
