defmodule MarketMySpec.ProblemDiscovery.JobPosting do
  @moduledoc """
  Raw posting fetched by Gather, one per `Source.search/1` result row.

  Carries the surface attributes Gather pulls from the source (title,
  description, money signals, url), the saved-search index that produced
  it (used by Pipeline.Gather for additive per-saved-search runs), a
  pgvector(1536) `embedding` computed once on insert via Embeddings, an
  optional `pain_descriptor` the agent writes during the 3-pass cluster
  refinement (`SetPainDescriptor` MCP tool), and a nullable `candidate_id`
  set by Cluster when the posting is grouped into a Candidate.

  belongs_to Frame (always) and Candidate (after Cluster runs).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.ProblemDiscovery.Candidate
  alias MarketMySpec.ProblemDiscovery.Frame
  alias MarketMySpec.ProblemDiscovery.PaidJobSignal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          frame_id: Ecto.UUID.t() | nil,
          candidate_id: Ecto.UUID.t() | nil,
          saved_search_index: integer() | nil,
          source: String.t() | nil,
          source_id: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          url: String.t() | nil,
          total_spent_cents: integer() | nil,
          hire_rate: integer() | nil,
          pain_descriptor: String.t() | nil,
          embedding: Pgvector.Vector.t() | nil,
          gathered_at: DateTime.t() | nil,
          frame: Frame.t() | Ecto.Association.NotLoaded.t(),
          candidate: Candidate.t() | nil | Ecto.Association.NotLoaded.t(),
          paid_job_signal: PaidJobSignal.t() | nil | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "problem_discovery_job_postings" do
    field :saved_search_index, :integer
    field :source, :string
    field :source_id, :string
    field :title, :string
    field :description, :string
    field :url, :string
    field :total_spent_cents, :integer
    field :hire_rate, :integer
    field :pain_descriptor, :string
    field :embedding, Pgvector.Ecto.Vector
    field :gathered_at, :utc_datetime

    belongs_to :frame, Frame
    belongs_to :candidate, Candidate

    has_one :paid_job_signal, PaidJobSignal

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :frame_id,
    :saved_search_index,
    :source,
    :source_id,
    :title,
    :description,
    :embedding,
    :gathered_at
  ]
  @optional_fields [
    :candidate_id,
    :url,
    :total_spent_cents,
    :hire_rate,
    :pain_descriptor
  ]

  @doc """
  Changeset for creating or updating a JobPosting.

  Embeddings are embed-once: produced on insert by Gather, never
  recomputed afterward. `pain_descriptor` and `candidate_id` are mutable
  post-insert — written by the agent via MCP tools (`SetPainDescriptor`)
  and by the Cluster stage respectively.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(posting, attrs) do
    posting
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:source_id,
      name: :problem_discovery_job_postings_frame_id_source_source_id_index
    )
    |> assoc_constraint(:frame)
    |> assoc_constraint(:candidate)
  end

  @doc """
  Changeset for an agent writing a pain_descriptor via the
  `SetPainDescriptor` MCP tool (pass 1 of the 3-pass cluster refinement).
  Only the `pain_descriptor` field changes.
  """
  @spec describe_pain_changeset(t(), String.t()) :: Ecto.Changeset.t()
  def describe_pain_changeset(posting, descriptor) when is_binary(descriptor) do
    posting
    |> cast(%{pain_descriptor: descriptor}, [:pain_descriptor])
    |> validate_required([:pain_descriptor])
    |> validate_length(:pain_descriptor, min: 1, max: 1024)
  end
end
