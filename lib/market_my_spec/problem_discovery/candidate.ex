defmodule MarketMySpec.ProblemDiscovery.Candidate do
  @moduledoc """
  Cluster output — groups JobPostings into a problem cluster.

  Each Candidate carries a 1536-dim `centroid` (mean of member JobPostings'
  embeddings, used by `pgvector` cosine-match for cross-rerun identity
  stability), an agent-provided `label` (assigned via `LabelCandidate` MCP
  tool — Path C splits algorithmic grouping from semantic naming), and an
  aggregated `score` (count of member PaidJobSignals classified `gated_in`).

  belongs_to Frame; has_many JobPosting; has_many PaidJobSignal;
  has_one RedTeamVerdict.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.ProblemDiscovery.Frame
  alias MarketMySpec.ProblemDiscovery.JobPosting
  alias MarketMySpec.ProblemDiscovery.PaidJobSignal
  alias MarketMySpec.ProblemDiscovery.RedTeamVerdict

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          frame_id: Ecto.UUID.t() | nil,
          label: String.t() | nil,
          score: integer() | nil,
          centroid: Pgvector.Vector.t() | nil,
          frame: Frame.t() | Ecto.Association.NotLoaded.t(),
          job_postings: [JobPosting.t()] | Ecto.Association.NotLoaded.t(),
          paid_job_signals: [PaidJobSignal.t()] | Ecto.Association.NotLoaded.t(),
          red_team_verdict: RedTeamVerdict.t() | nil | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "problem_discovery_candidates" do
    field :label, :string
    field :score, :integer, default: 0
    field :centroid, Pgvector.Ecto.Vector

    belongs_to :frame, Frame

    has_many :job_postings, JobPosting
    has_many :paid_job_signals, PaidJobSignal
    has_one :red_team_verdict, RedTeamVerdict

    timestamps(type: :utc_datetime)
  end

  @required_fields [:frame_id, :centroid]
  @optional_fields [:label, :score]

  @doc """
  Changeset for creating or updating a Candidate.

  `frame_id` and `centroid` are required; KMeans never produces a
  Candidate without a centroid. `label` and `score` are mutable post-hoc:
  the agent's `LabelCandidate` MCP tool writes the label after the 3-pass
  refinement; `score` is recomputed by Score per rerun.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(candidate, attrs) do
    candidate
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> assoc_constraint(:frame)
  end
end
