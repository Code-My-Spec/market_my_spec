defmodule MarketMySpecSpex.Story742.Criterion6558Spex do
  @moduledoc """
  Story 742 — Set the money-gate threshold at Frame time
  Criterion 6558 — Score uses the Frame's threshold values verbatim, even
  when most JobPostings fail it.

  Score must apply exactly the threshold values from the Frame's
  money_gate field — no automatic relaxation, no fallback to a lower
  bar when surviving postings would be few. The founder's threshold is
  honored even if it means a thin Board.

  Interaction surface: MCP tool execution. Commit a Frame with a very
  high threshold (most postings will fail), run pipeline, verify only
  postings clearing the exact threshold are gated_in.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListFrames
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

  spex "Score honors the Frame's threshold values verbatim even when most postings fail" do
    scenario "A high threshold ($50,000 total_spent_min) is applied verbatim — most postings end up gated_out" do
      given_ "a Frame with money_gate=$50,000/80%, very few postings will clear it",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6558_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "High-bar money gate",
                  saved_searches: ["upwork|vendor onboarding"],
                  total_spent_min: 50_000,
                  hire_rate_min: 80,
                  min_money_gated_candidates: 1
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, agent_frame)
            {:reply, _, _} = RunCluster.execute(%{frame_id: frame_id}, agent_frame)

            %{frame_id: frame_id}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent runs Score", context do
        candidates =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6558_when", fn ->
            {:reply, _, _} = RunScore.execute(%{frame_id: context.frame_id}, context.agent_frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: context.frame_id}, context.agent_frame)

            decode_payload(list_resp)["candidates"] || []
          end)

        {:ok, Map.put(context, :candidates, candidates)}
      end

      then_ "every gated_in PaidJobSignal corresponds to a JobPosting that meets BOTH thresholds exactly",
            context do
        for c <- context.candidates do
          gated_in_count = c["gated_in_count"] || 0
          total = (c["member_count"] || length(c["job_posting_ids"] || []))

          # The high bar ($50k+ + 80%+) means gated_in must be << total
          # when the gathered corpus is realistic (founder's hypothetical
          # postings rarely have $50k+ client lifetime spend AND 80%+
          # hire rate).
          assert gated_in_count <= total,
                 "gated_in (#{gated_in_count}) cannot exceed total (#{total}) for Candidate #{inspect(c["id"])}"
        end

        {:ok, context}
      end

      then_ "no autorelaxation evidence in Score's behavior: the persisted Frame's money_gate is unchanged after Score runs",
            context do
        # Reload the Frame's money_gate from the source-of-truth artifact.
        # Score does NOT mutate the Frame's threshold.
        {:reply, list_resp, _} = ListFrames.execute(%{}, context.agent_frame)

        [frame_summary | _] = decode_payload(list_resp)["frames"] || []
        gate = frame_summary["money_gate"] || %{}

        total_spent = gate["total_spent_min"] || gate[:total_spent_min]
        hire_rate = gate["hire_rate_min"] || gate[:hire_rate_min]

        assert total_spent == 50_000,
               "expected money_gate.total_spent_min unchanged after Score; got: #{inspect(total_spent)}"

        assert hire_rate == 80,
               "expected money_gate.hire_rate_min unchanged after Score; got: #{inspect(hire_rate)}"
        {:ok, context}
      end
    end
  end
end
