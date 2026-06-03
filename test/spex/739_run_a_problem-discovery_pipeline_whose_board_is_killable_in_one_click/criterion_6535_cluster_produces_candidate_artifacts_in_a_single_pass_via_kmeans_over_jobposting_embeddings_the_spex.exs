defmodule MarketMySpecSpex.Story739.Criterion6535Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6535 — Cluster produces Candidate artifacts in a single pass via KMeans
  over JobPosting embeddings; the 3-pass agent refinement (pain descriptors per
  JobPosting via SetPainDescriptor, consolidate/split Candidates via MergeCandidates/
  SplitCandidate, label via LabelCandidate) is a separate post-Cluster MCP-tool
  surface, not additional MMS-internal Cluster passes.

  RunCluster runs exactly one KMeans pass and persists Candidates. Any
  subsequent semantic refinement happens through separate MCP tool calls
  the agent invokes (SetPainDescriptor, MergeCandidates, SplitCandidate,
  LabelCandidate) — those tools do not re-run Cluster internally.

  Interaction surface: MCP tool execution. Asserts the post-RunCluster state
  has Candidates with mechanical (un-labeled) attributes, and that the
  agent-refinement tools mutate Candidates in place without re-running KMeans.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.LabelCandidate
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.SetPainDescriptor
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

  spex "Cluster is one KMeans pass; agent refinement is a separate MCP-tool surface" do
    scenario "RunCluster persists Candidates with no semantic labels; SetPainDescriptor and LabelCandidate mutate in place without re-running KMeans" do
      given_ "a Frame with gathered JobPostings", context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6535_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Single-pass cluster validation",
                  saved_searches: [
                    %{source: "upwork", query: "vendor onboarding"},
                    %{source: "upwork", query: "supplier consolidation"},
                    %{source: "upwork", query: "intake automation"}
                  ],
                  money_gate: %{total_spent_min: 5_000, hire_rate_min: 50},
                  kill_condition: %{min_money_gated_candidates: 1}
                },
                frame
              )

            frame_id = decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, frame)

            %{frame_id: frame_id}
          end)

        {:ok, Map.merge(context, Map.put(result, :frame, frame))}
      end

      when_ "the agent runs Cluster once, then runs SetPainDescriptor and LabelCandidate as separate MCP-tool calls",
            context do
        post_cluster =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6535_when", fn ->
            {:reply, _, _} = RunCluster.execute(%{frame_id: context.frame_id}, context.frame)

            {:reply, post_cluster_resp, _} =
              ListCandidates.execute(%{frame_id: context.frame_id}, context.frame)

            decode_payload(post_cluster_resp)["candidates"] || []
          end)

        cluster_id_set =
          post_cluster |> Enum.map(fn c -> c["id"] || c[:id] end) |> MapSet.new()

        for candidate <- post_cluster do
          candidate_id = candidate["id"] || candidate[:id]
          job_posting_ids = candidate["job_posting_ids"] || candidate[:job_posting_ids] || []

          for jp_id <- job_posting_ids do
            {:reply, _, _} =
              SetPainDescriptor.execute(
                %{job_posting_id: jp_id, pain_descriptor: "agent-written pain summary"},
                context.frame
              )
          end

          {:reply, _, _} =
            LabelCandidate.execute(
              %{candidate_id: candidate_id, label: "agent-derived semantic label"},
              context.frame
            )
        end

        {:reply, post_refinement_resp, _} =
          ListCandidates.execute(%{frame_id: context.frame_id}, context.frame)

        post_refinement = decode_payload(post_refinement_resp)["candidates"] || []

        {:ok,
         Map.merge(context, %{
           post_cluster_candidates: post_cluster,
           post_cluster_ids: cluster_id_set,
           post_refinement_candidates: post_refinement
         })}
      end

      then_ "post-Cluster Candidates carried mechanical (unlabeled) attributes — no semantic label from KMeans itself",
            context do
        for cand <- context.post_cluster_candidates do
          label = cand["label"] || cand[:label]

          assert is_nil(label) or label == "" or label == "unlabeled",
                 "expected post-KMeans Candidate to have no semantic label; got: #{inspect(label)}"
        end

        {:ok, context}
      end

      then_ "after agent refinement, Candidate ids are the same set as immediately post-Cluster — no re-clustering",
            context do
        post_refinement_ids =
          context.post_refinement_candidates
          |> Enum.map(fn c -> c["id"] || c[:id] end)
          |> MapSet.new()

        assert MapSet.equal?(post_refinement_ids, context.post_cluster_ids),
               "expected Candidate id set after agent refinement to equal the post-Cluster set (no KMeans re-run); pre: #{inspect(MapSet.to_list(context.post_cluster_ids))}, post: #{inspect(MapSet.to_list(post_refinement_ids))}"

        {:ok, context}
      end

      then_ "after agent refinement, the Candidates now carry agent-written labels",
            context do
        for cand <- context.post_refinement_candidates do
          label = cand["label"] || cand[:label]

          assert label == "agent-derived semantic label",
                 "expected agent-written label on every Candidate after refinement; got: #{inspect(label)}"
        end

        {:ok, context}
      end
    end
  end
end
