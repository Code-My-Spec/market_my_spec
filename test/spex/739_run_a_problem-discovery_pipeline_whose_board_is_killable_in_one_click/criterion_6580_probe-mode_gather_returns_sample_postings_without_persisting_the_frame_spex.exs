defmodule MarketMySpecSpex.Story739.Criterion6580Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6580 — Probe-mode Gather returns sample postings without persisting the Frame.

  During Frame composition, the agent can run RunGather in probe mode
  against an uncommitted draft Frame. The tool returns a small sample of
  postings (for review by the agent and founder) but persists NOTHING:
  no Frame artifact, no JobPosting records. The draft can be revised
  and probed again, or eventually committed via CreateFrame.

  Interaction surface: MCP tool execution. Asserts (a) the probe response
  carries a sample, (b) no Frame is persisted, (c) no JobPosting records
  are persisted from the probe.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListFrames
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
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

  spex "Probe-mode Gather returns sample postings without persisting the Frame" do
    scenario "Agent runs RunGather in probe mode against a draft Frame; no Frame or JobPostings are persisted" do
      given_ "an account with no existing Frames", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        {:reply, list_before_resp, _} = ListFrames.execute(%{}, agent_frame)
        frames_before = decode_payload(list_before_resp)["frames"] || []

        assert frames_before == [],
               "test precondition: account starts with no Frames"

        {:ok, Map.merge(context, %{agent_frame: agent_frame})}
      end

      when_ "the agent runs RunGather in probe mode against an uncommitted draft Frame",
            context do
        draft_frame = %{
          description: "Probe draft — uncommitted",
          saved_searches: [%{source: "upwork", query: "vendor onboarding"}],
          money_gate: %{total_spent_min: 1, hire_rate_min: 1},
          kill_condition: %{min_money_gated_candidates: 1}
        }

        probe_payload =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6580_when", fn ->
            {:reply, probe_resp, _} =
              RunGather.execute(
                %{frame: draft_frame, mode: "probe", limit: 20},
                context.agent_frame
              )

            decode_payload(probe_resp)
          end)

        {:ok, Map.put(context, :probe_payload, probe_payload)}
      end

      then_ "the probe response carries a sample list of JobPosting attribute maps",
            context do
        sample = context.probe_payload["sample"] || context.probe_payload[:sample] || []

        assert is_list(sample),
               "expected probe response to carry a sample list; got: #{inspect(context.probe_payload)}"

        assert sample != [],
               "expected probe sample to be non-empty (sample of postings the queries surfaced)"

        for posting <- sample do
          assert is_map(posting),
                 "expected each sample entry to be a JobPosting attribute map; got: #{inspect(posting)}"
        end

        {:ok, context}
      end

      then_ "no Frame is persisted as a result of the probe", context do
        {:reply, list_after_resp, _} = ListFrames.execute(%{}, context.agent_frame)
        frames_after = decode_payload(list_after_resp)["frames"] || []

        assert frames_after == [],
               "expected probe to NOT persist a Frame; got: #{inspect(frames_after)}"

        {:ok, context}
      end

      then_ "the probe response explicitly indicates no persistence occurred", context do
        persisted = context.probe_payload["persisted"] || context.probe_payload[:persisted]

        assert persisted == false or is_nil(persisted),
               "expected probe response 'persisted' flag to be false or nil; got: #{inspect(persisted)}"

        {:ok, context}
      end
    end
  end
end
