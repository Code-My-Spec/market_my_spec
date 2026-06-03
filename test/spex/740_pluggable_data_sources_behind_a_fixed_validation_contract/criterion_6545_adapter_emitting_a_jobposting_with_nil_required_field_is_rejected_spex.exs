defmodule MarketMySpecSpex.Story740.Criterion6545Spex do
  @moduledoc """
  Story 740 — Pluggable data sources behind a fixed validation contract
  Criterion 6545 — Adapter emitting a JobPosting with nil required field
  is rejected at Gather time.

  The JobPosting schema's changeset enforces required fields (per rule
  c4c3e570: source, source_id, title, description, embedding, frame_id,
  saved_search_index, gathered_at). When the Pipeline.Gather stage
  inserts a posting whose attrs are missing a required field, the
  insert must fail with a changeset error — not silently swallow it.

  Interaction surface: changeset validation directly on the JobPosting
  schema (the structural enforcement point).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.ProblemDiscovery.JobPosting

  @required_field :title

  spex "JobPosting with a nil required field is rejected by the changeset" do
    scenario "Building a JobPosting changeset with title=nil fails validation" do
      given_ "a posting attribute map that's missing the required `title` field",
             context do
        attrs = %{
          frame_id: Ecto.UUID.generate(),
          saved_search_index: 0,
          source: "upwork",
          source_id: "abc-123",
          # title intentionally omitted
          description: "Some description.",
          embedding: List.duplicate(0.0, 1536) |> Pgvector.new(),
          gathered_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }

        {:ok, Map.put(context, :attrs, attrs)}
      end

      when_ "the agent builds a JobPosting changeset from those attrs", context do
        changeset = JobPosting.changeset(%JobPosting{}, context.attrs)

        {:ok, Map.put(context, :changeset, changeset)}
      end

      then_ "the changeset is invalid and reports an error on the missing required field",
            context do
        refute context.changeset.valid?,
               "expected the changeset to be invalid (missing required field); got valid"

        errors = Keyword.keys(context.changeset.errors)

        assert @required_field in errors,
               "expected a changeset error on :#{@required_field}; got errors on: #{inspect(errors)}"
        {:ok, context}
      end
    end
  end
end
