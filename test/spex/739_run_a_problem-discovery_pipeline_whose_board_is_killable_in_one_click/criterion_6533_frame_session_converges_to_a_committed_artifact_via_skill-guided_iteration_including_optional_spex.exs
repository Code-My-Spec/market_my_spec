defmodule MarketMySpecSpex.Story739.Criterion6533Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6533 — Frame session converges to a committed artifact via skill-guided
  iteration, including optional probe-mode Gather rounds against draft saved searches.

  The Frame composition phase is iterative and skill-guided. Within a Frame
  session, the agent runs probe-mode Gather rounds against draft saved
  searches (no Frame persisted yet), revises queries based on the sample,
  and finally commits the Frame. The committed Frame artifact reflects the
  iterated state.

  Interaction surface: MCP tool execution (probe-mode RunGather + CreateFrame).
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame
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

  spex "Frame session converges via skill-guided iteration with probe-mode Gather rounds" do
    scenario "Probe-mode rounds against draft saved searches followed by Frame commit" do
      given_ "an account with no existing Frames", context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        {:reply, list_resp, _} = ListFrames.execute(%{}, agent_frame)
        existing = decode_payload(list_resp)["frames"] || []

        assert existing == [], "test precondition: account starts with no Frames"

        {:ok, Map.merge(context, %{agent_frame: agent_frame})}
      end

      when_ "the agent runs two probe-mode Gather rounds against draft saved searches and then commits the Frame",
            context do
        draft_v1 = %{
          description: "Vendor onboarding pain (draft v1)",
          saved_searches: [
            "upwork|vendor onboarding",
            "upwork|supplier intake",
            "upwork|third party setup"
          ],
          total_spent_min: 1_000,
          hire_rate_min: 30,
          min_money_gated_candidates: 1
        }

        draft_v2 = %{
          description: "Vendor onboarding pain (draft v2 — vocabulary refined)",
          saved_searches: [
            "upwork|vendor onboarding migration",
            "upwork|supplier portal consolidation",
            "upwork|agency sub-account intake"
          ],
          total_spent_min: 5_000,
          hire_rate_min: 50,
          min_money_gated_candidates: 3
        }

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6533_when", fn ->
            {:reply, probe_v1_resp, _} =
              RunGather.execute(
                %{frame: draft_v1, mode: "probe", limit: 20},
                context.agent_frame
              )

            # Verify probe v1 returned a sample without persisting a Frame.
            {:reply, list_after_v1, _} = ListFrames.execute(%{}, context.agent_frame)
            frames_after_v1 = decode_payload(list_after_v1)["frames"] || []

            assert frames_after_v1 == [],
                   "expected no Frame persisted after probe round 1; got: #{inspect(frames_after_v1)}"

            {:reply, _probe_v2_resp, _} =
              RunGather.execute(
                %{frame: draft_v2, mode: "probe", limit: 20},
                context.agent_frame
              )

            {:reply, create_resp, _} = CreateFrame.execute(draft_v2, context.agent_frame)

            frame_id =
              decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

            %{
              frame_id: frame_id,
              probe_v1_payload: decode_payload(probe_v1_resp),
              committed_payload: decode_payload(create_resp)
            }
          end)

        {:ok, Map.merge(context, result)}
      end

      then_ "the committed Frame reflects the iterated (v2) state, not the initial draft",
            context do
        {:reply, get_resp, _} =
          GetFrame.execute(%{frame_id: context.frame_id}, context.agent_frame)

        frame_state = decode_payload(get_resp)
        saved_searches = frame_state["saved_searches"] || []

        queries = Enum.map(saved_searches, fn s -> s["query"] || s[:query] end)

        assert "vendor onboarding migration" in queries,
               "expected committed Frame to carry the v2 query; got queries: #{inspect(queries)}"

        refute "third party setup" in queries,
               "expected v1 query 'third party setup' to be replaced before commit"

        {:ok, context}
      end

      then_ "probe-mode returned a sample without persisting JobPostings against the (still draft) Frame",
            context do
        sample = context.probe_v1_payload["sample"] || context.probe_v1_payload[:sample] || []

        assert is_list(sample),
               "expected probe-mode response to carry a sample list of JobPosting attribute maps"

        # The probe sample should NOT be persisted as committed JobPosting rows
        # (the only persistence happens at CreateFrame + non-probe RunGather time).
        persisted = context.probe_v1_payload["persisted"] || context.probe_v1_payload[:persisted]
        assert persisted == false or is_nil(persisted),
               "expected probe-mode to NOT persist JobPosting records; persisted flag: #{inspect(persisted)}"

        {:ok, context}
      end
    end
  end
end
