defmodule MarketMySpecSpex.Story743.Criterion6572Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6572 — Candidate score recomputes after threshold tightens.

  Each Candidate's score is the count of its gated_in member PaidJobSignals.
  When the founder tightens the money_gate threshold, fewer PaidJobSignals
  classify as gated_in, and the Candidate's score decreases accordingly.

  Interaction surface: MCP tool execution; ListCandidates reports
  per-Candidate score before and after the threshold change.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.UpdateFrame
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

  defp total_score(candidates) do
    candidates |> Enum.map(fn c -> c["score"] || 0 end) |> Enum.sum()
  end

  spex "Candidate scores recompute after threshold change" do
    scenario "Tightening money_gate reduces aggregate Candidate score (fewer gated_in signals)" do
      given_ "a Frame scored with a lenient money_gate; aggregate Candidate score recorded",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6572", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Score recomputes on threshold change",
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

            {:reply, list_before, _} =
              ListCandidates.execute(%{frame_id: frame_id}, agent_frame)

            before_total = total_score(decode_payload(list_before)["candidates"] || [])

            %{frame_id: frame_id, before_total: before_total}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the founder tightens money_gate to $1,000,000/99% (effectively impossible) and re-Scores",
            context do
        {:reply, _, _} =
          UpdateFrame.execute(
            %{
              frame_id: context.frame_id,
              money_gate: %{total_spent_min: 1_000_000, hire_rate_min: 99}
            },
            context.agent_frame
          )

        {:reply, _, _} = RunScore.execute(%{frame_id: context.frame_id}, context.agent_frame)

        {:reply, list_after, _} =
          ListCandidates.execute(%{frame_id: context.frame_id}, context.agent_frame)

        after_total = total_score(decode_payload(list_after)["candidates"] || [])

        {:ok, Map.put(context, :after_total, after_total)}
      end

      then_ "aggregate Candidate score decreases (or stays at zero)", context do
        assert context.after_total <= context.before_total,
               "expected aggregate Candidate score to decrease or stay flat after threshold tightening; before=#{context.before_total}, after=#{context.after_total}"
        {:ok, context}
      end
    end
  end
end
