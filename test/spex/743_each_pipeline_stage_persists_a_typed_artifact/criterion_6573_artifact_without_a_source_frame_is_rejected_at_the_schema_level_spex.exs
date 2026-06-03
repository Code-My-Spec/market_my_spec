defmodule MarketMySpecSpex.Story743.Criterion6573Spex do
  @moduledoc """
  Story 743 — Each pipeline stage persists a typed artifact
  Criterion 6573 — Artifact without a source Frame is rejected at the
  schema level.

  Every per-Frame artifact (JobPosting, Candidate) must carry a frame_id
  FK. Attempting to insert one without a frame_id must fail at the
  changeset validation layer — the schema does not allow orphan
  artifacts.

  Interaction surface: changeset-level validation on JobPosting and
  Candidate schemas.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.Candidate
  alias MarketMySpec.ProblemDiscovery.JobPosting

  spex "Per-Frame artifacts reject inserts without a frame_id" do
    scenario "JobPosting changeset without frame_id is invalid" do
      given_ "a JobPosting attribute map missing frame_id", context do
        attrs = %{
          saved_search_index: 0,
          source: "upwork",
          source_id: "abc",
          title: "A title",
          description: "A description",
          embedding: List.duplicate(0.0, 1536) |> Pgvector.new(),
          gathered_at: DateTime.utc_now() |> DateTime.truncate(:second)
          # frame_id intentionally omitted
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds a JobPosting changeset", context do
        changeset = JobPosting.changeset(%JobPosting{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with a frame_id error", context do
        refute context.changeset.valid?,
               "expected JobPosting changeset to be invalid without frame_id"

        assert :frame_id in Keyword.keys(context.changeset.errors),
               "expected error on :frame_id; got errors on: #{inspect(Keyword.keys(context.changeset.errors))}"
        {:ok, context}
      end
    end

    scenario "Candidate changeset without frame_id is invalid" do
      given_ "a Candidate attribute map missing frame_id", context do
        attrs = %{
          centroid: List.duplicate(0.0, 1536) |> Pgvector.new()
          # frame_id intentionally omitted
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds a Candidate changeset", context do
        changeset = Candidate.changeset(%Candidate{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid with a frame_id error", context do
        refute context.changeset.valid?,
               "expected Candidate changeset to be invalid without frame_id"

        assert :frame_id in Keyword.keys(context.changeset.errors)
        {:ok, context}
      end
    end
  end
end
