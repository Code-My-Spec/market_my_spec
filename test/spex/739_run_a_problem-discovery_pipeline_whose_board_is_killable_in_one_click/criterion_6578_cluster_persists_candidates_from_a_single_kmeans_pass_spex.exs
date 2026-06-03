defmodule MarketMySpecSpex.Story739.Criterion6578Spex do
  @moduledoc """
  Story 739 — Run a problem-discovery pipeline whose board is killable in one click
  Criterion 6578 — Cluster persists Candidates from a single KMeans pass.

  Given a Frame with N gathered JobPostings (each carrying a 1536-dim
  embedding), RunCluster invokes Scholar.Cluster.KMeans.fit/2 exactly
  once, then persists Candidates in one batch. Each Candidate carries a
  centroid equal to the mean of its member embeddings. No LLM completion
  call is issued during the Cluster stage.

  Interaction surface: MCP tool execution. Asserts (a) Candidates appear
  in a single batch (single insertion timestamp), (b) each Candidate's
  centroid matches the mean of its member JobPostings' embeddings.
  """

  use MarketMySpecSpex.Case

  alias Anubis.Server.Response
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates
  alias MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster
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

  spex "Cluster persists Candidates from a single KMeans pass" do
    scenario "RunCluster on a Frame with 200 gathered JobPostings produces a single batch of Candidates with mean-of-members centroids" do
      given_ "a Frame whose Gather produced approximately 200 JobPostings, each with an embedding",
             context do
        scope = Fixtures.account_scoped_user_fixture()
        frame = build_frame(scope)

        result =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6578_given", fn ->
            {:reply, create_resp, _} =
              CreateFrame.execute(
                %{
                  description: "Single-pass KMeans persistence",
                  saved_searches: [
                    "upwork|vendor onboarding",
                    "upwork|supplier consolidation",
                    "upwork|intake automation"
                  ],
                  total_spent_min: 5_000,
                  hire_rate_min: 50,
                  min_money_gated_candidates: 1
                },
                frame
              )

            frame_id =
              decode_payload(create_resp)["frame_id"] || decode_payload(create_resp)["id"]

            {:reply, _, _} = RunGather.execute(%{frame_id: frame_id}, frame)

            %{frame_id: frame_id}
          end)

        {:ok, Map.merge(context, Map.put(result, :frame, frame))}
      end

      when_ "the agent invokes RunCluster", context do
        candidates =
          ProblemDiscoveryHelpers.with_problem_discovery_cassette("criterion_6578_when", fn ->
            {:reply, _, _} = RunCluster.execute(%{frame_id: context.frame_id}, context.frame)

            {:reply, list_resp, _} =
              ListCandidates.execute(%{frame_id: context.frame_id}, context.frame)

            decode_payload(list_resp)["candidates"] || []
          end)

        {:ok, Map.put(context, :candidates, candidates)}
      end

      then_ "all Candidates were inserted in a single batch (identical inserted_at timestamps)",
            context do
        timestamps =
          context.candidates
          |> Enum.map(fn c -> c["inserted_at"] || c[:inserted_at] end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        assert length(timestamps) == 1,
               "expected all Candidates to share a single inserted_at timestamp (one batch); got distinct: #{inspect(timestamps)}"

        {:ok, context}
      end

      then_ "each Candidate's centroid equals the mean of its member JobPostings' embeddings",
            context do
        for cand <- context.candidates do
          centroid = cand["centroid"] || cand[:centroid]
          member_embeddings = cand["member_embeddings"] || cand[:member_embeddings] || []

          assert is_list(member_embeddings) and member_embeddings != [],
                 "expected non-empty member_embeddings for Candidate #{inspect(cand["id"] || cand[:id])}"

          dim = length(hd(member_embeddings))

          expected_centroid =
            for i <- 0..(dim - 1) do
              sum = Enum.reduce(member_embeddings, 0.0, fn vec, acc -> acc + Enum.at(vec, i) end)
              sum / length(member_embeddings)
            end

          for {actual, expected} <- Enum.zip(centroid, expected_centroid) do
            assert_in_delta actual, expected, 0.0001
          end
        end

        {:ok, context}
      end
    end
  end
end
