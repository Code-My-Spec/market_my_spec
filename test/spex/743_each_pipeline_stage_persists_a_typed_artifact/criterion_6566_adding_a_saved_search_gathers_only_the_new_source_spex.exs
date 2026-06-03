defmodule MarketMySpecSpex.Story743.Criterion6566Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6566 — Adding a saved search gathers only the new source.

  Gather is additive per-saved-search. When the founder adds a new
  saved search to a Frame and re-runs Gather, only the new saved search
  triggers fetches against the corpus source — previously-gathered
  saved searches are skipped (their JobPostings already exist).

  Interaction surface: MCP tool execution (UpdateFrame + second
  RunGather), counting per-saved-search-index JobPostings before and
  after.
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

  spex "Gather is per-saved-search additive — adding one search gathers only the new one" do
    scenario "Frame with 2 already-gathered saved searches plus a new third — second RunGather only reports the third" do
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

      then_ "the second Gather run only invokes the third saved search (the first two are skipped)",
            context do
        per_search = context.second_gather_payload["per_saved_search"] || []

        skipped =
          Enum.filter(per_search, fn entry -> entry["skipped"] == true end)

        not_skipped =
          Enum.reject(per_search, fn entry -> entry["skipped"] == true end)

        assert length(skipped) == 2,
               "expected 2 saved searches to be skipped on re-Gather; got: #{inspect(per_search)}"

        assert length(not_skipped) == 1,
               "expected 1 saved search to gather (the new third one); got: #{inspect(per_search)}"
        {:ok, context}
      end
    end
  end
end
