defmodule MarketMySpecSpex.Story739.Criterion6526Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6526 — Surviving candidate exposes at least one openable verification link.

  A surviving Candidate on the Board (one that wasn't dropped pre-Board for
  lack of evidence) must expose at least one externally-openable URL — a
  link back to a source JobPosting, paid product page, or other artifact
  the founder can click to verify the evidence with their own eyes.

  Interaction surface: MCP tool execution (GetBoard returns Candidate rows
  whose evidence carries URLs).
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

  defp openable_url?(url) when is_binary(url) do
    String.starts_with?(url, "http://") or String.starts_with?(url, "https://")
  end

  defp openable_url?(_), do: false

  spex "Every surviving Candidate exposes at least one openable verification link" do
    scenario "Board's Candidates each carry one or more openable URLs in their evidence" do
      given_ "a Frame has been committed and the pipeline has run end-to-end", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6526_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Vendor migration pain",
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

            %{frame: frame, frame_id: frame_id}
          end)

        {:ok, Map.merge(context, result)}
      end

      when_ "the agent fetches the Board", context do
        {:reply, board_resp, _} =
          GetBoard.execute(%{frame_id: context.frame_id}, context.frame)

        {:ok, Map.put(context, :board, decode_payload(board_resp))}
      end

      then_ "every surviving Candidate exposes at least one externally-openable URL",
            context do
        candidates = context.board["candidates"] || context.board[:candidates] || []

        assert candidates != [],
               "expected non-empty Board to validate verification links against"

        for row <- candidates do
          links = row["verification_links"] || row[:verification_links] || []

          assert is_list(links),
                 "expected verification_links to be a list on row #{inspect(row["label"] || row[:label])}"

          assert Enum.any?(links, &openable_url?/1),
                 "expected at least one openable http(s) URL on row #{inspect(row["label"] || row[:label])}; got: #{inspect(links)}"
        end

        {:ok, context}
      end
    end
  end
end
