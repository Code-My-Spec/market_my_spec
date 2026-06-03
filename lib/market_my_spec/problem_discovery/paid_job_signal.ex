defmodule MarketMySpec.ProblemDiscovery.PaidJobSignal do
  @moduledoc """
  Score output — per-JobPosting evaluation against the Frame's `money_gate`.

  Carries a `classification` field (`:gated_in` | `:gated_out`) that Score
  writes. Changing the money_gate threshold and re-running Score
  **rewrites** this field in place; no PaidJobSignal records are created or
  deleted (story 743 rule 8; the rerun-classification invariant lets the
  founder explore threshold sensitivity without re-paying for the corpus).

  belongs_to JobPosting (one-to-one — exactly one PaidJobSignal per
  JobPosting) and Candidate (denormalized for fast per-cluster aggregate
  queries; cascade-delete if the Candidate goes away).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.ProblemDiscovery.Candidate
  alias MarketMySpec.ProblemDiscovery.JobPosting

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type classification :: :gated_in | :gated_out

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          job_posting_id: Ecto.UUID.t() | nil,
          candidate_id: Ecto.UUID.t() | nil,
          classification: classification() | nil,
          job_posting: JobPosting.t() | Ecto.Association.NotLoaded.t(),
          candidate: Candidate.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "problem_discovery_paid_job_signals" do
    field :classification, Ecto.Enum, values: [:gated_in, :gated_out]

    belongs_to :job_posting, JobPosting
    belongs_to :candidate, Candidate

    timestamps(type: :utc_datetime)
  end

  @required_fields [:job_posting_id, :candidate_id, :classification]

  @doc """
  Changeset for creating a PaidJobSignal (Score's first run on a JobPosting).
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(signal, attrs) do
    signal
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:job_posting_id)
    |> assoc_constraint(:job_posting)
    |> assoc_constraint(:candidate)
  end

  @doc """
  Changeset for re-classifying an existing PaidJobSignal when the Frame's
  money_gate changes and Score re-runs. Only the `classification` field
  changes — no record creation, no record deletion (story 743 rule 8).
  """
  @spec reclassify_changeset(t(), classification()) :: Ecto.Changeset.t()
  def reclassify_changeset(signal, classification)
      when classification in [:gated_in, :gated_out] do
    signal
    |> cast(%{classification: classification}, [:classification])
    |> validate_required([:classification])
  end
end
