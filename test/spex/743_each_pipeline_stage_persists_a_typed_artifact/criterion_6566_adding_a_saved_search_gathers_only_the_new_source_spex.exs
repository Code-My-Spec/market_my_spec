defmodule MarketMySpecSpex.Story743.Criterion6566Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6566 — Re-Gather is per-saved-search and skips successful
  prior gathers; zero-result searches retry so a malformed query can
  be refined without losing rerun cheapness elsewhere.

  Mark-on-success semantics: a saved_search gets `gathered_at` set
  only when the adapter returned rows. A search that returned zero
  rows is surfaced with `zero_results: true` in the per-saved-search
  payload and left unmarked, so the next RunGather retries it
  (no `--force` needed). This protects the core MMS conviction story
  by keeping "this query was malformed" distinguishable from "this
  market genuinely has no demand."

  Interaction surface: MCP tool execution (UpdateFrame + second
  RunGather), inspecting the per-saved-search return payload.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
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

  spex "Re-Gather skips searches that produced rows; zero-result and new searches re-run" do
    scenario "Frame with one row-yielding search + one zero-result search + a new third — second RunGather skips only the row-yielding one" do
      given_ "a Frame with 2 saved searches whose initial Gather has populated JobPostings",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        agent_frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6566_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Additive Gather",
                  saved_searches: [
                    "upwork|vendor onboarding",
                    "upwork|supplier consolidation"
                  ],
                  total_spent_min: 1_000,
                  hire_rate_min: 30,
                  min_money_gated_candidates: 1
                },
                agent_frame
              )

            frame_id = decode_payload(create_resp)["frame_id"]

            {:reply, _first_gather, _} =
              RunGather.execute(%{frame_id: frame_id}, agent_frame)

            {:reply, frame_after_first, _} =
              GetFrame.execute(%{frame_id: frame_id}, agent_frame)

            jp_count_after_first =
              decode_payload(frame_after_first)["artifacts"]["JobPosting"] || 0

            %{frame_id: frame_id, jp_count_after_first: jp_count_after_first}
          end)

        {:ok, Map.merge(context, Map.put(result, :agent_frame, agent_frame))}
      end

      when_ "the agent adds a third saved search to the Frame and re-runs Gather",
            context do
        second_gather_payload =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6566_when", fn ->
            {:reply, _, _} =
              UpdateFrame.execute(
                %{
                  frame_id: context.frame_id,
                  saved_searches: [
                    "upwork|vendor onboarding",
                    "upwork|supplier consolidation",
                    "upwork|agency intake"
                  ]
                },
                context.agent_frame
              )

            {:reply, second_gather, _} =
              RunGather.execute(%{frame_id: context.frame_id}, context.agent_frame)

            decode_payload(second_gather)
          end)

        {:ok, Map.put(context, :second_gather_payload, second_gather_payload)}
      end

      then_ "the second Gather run skips searches that gathered rows; zero-result + new searches re-run",
            context do
        # New mark-on-success semantics: a saved_search gets `gathered_at`
        # set only when the adapter returns rows. Empty-result responses
        # come back with `zero_results: true` and stay unmarked so the
        # agent can refine + retry (or the next RunGather just retries).
        #
        # In this scenario:
        #   - "vendor onboarding"      → had rows in given_   → SKIP on re-run
        #   - "supplier consolidation" → 0 results in given_  → zero_results, NOT skipped
        #   - "agency intake" (new)    → never gathered       → runs
        per_search = context.second_gather_payload["per_saved_search"] || []

        skipped = Enum.filter(per_search, fn entry -> entry["skipped"] == true end)

        zero_or_new =
          Enum.reject(per_search, fn entry -> entry["skipped"] == true end)

        assert length(skipped) == 1,
               "expected 1 already-gathered saved search to skip on re-Gather; got: #{inspect(per_search)}"

        assert length(zero_or_new) == 2,
               "expected 2 saved searches to gather (1 zero-result retry + 1 new); got: #{inspect(per_search)}"

        zero_result_entry =
          Enum.find(zero_or_new, fn entry -> entry["zero_results"] == true end)

        assert zero_result_entry,
               "expected the zero-result saved search to surface `zero_results: true` so the agent can refine; got: #{inspect(zero_or_new)}"

        {:ok, context}
      end
    end
  end
end
