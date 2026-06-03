defmodule MarketMySpec.ProblemDiscovery.RedTeamVerdict do
  @moduledoc """
  Red-team output — per-Candidate prosecution from the same evidence that
  promoted it (story 741).

  Produced conversationally by the agent one Candidate at a time
  (`RedTeamCandidate` MCP tool, per Klein past-tense pre-mortem framing).
  The verdict overwrites Score's mechanical verdict on the Board.

  Verdict values are the four canonical outcomes:
  - `:keep_productizable` — strong money signal, prosecuted, work is
    productizable (a tool could substitute for the freelance specialist).
  - `:keep_service_only` — strong money signal, prosecuted, but the work
    requires human judgment a tool cannot replace. A services lead, not
    a product lead.
  - `:watch` — signal is real but thin or concentrated; not enough to
    commit but worth re-checking with more data.
  - `:kill` — kill argument survived; the founder cannot credibly answer
    it from the evidence.

  belongs_to Candidate (one-to-one — at most one verdict per Candidate; a
  new RedTeamCandidate call overwrites the existing verdict).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.ProblemDiscovery.Candidate

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type verdict :: :keep_productizable | :keep_service_only | :watch | :kill

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          candidate_id: Ecto.UUID.t() | nil,
          verdict: verdict() | nil,
          kill_argument: String.t() | nil,
          cheapest_kill_test: String.t() | nil,
          candidate: Candidate.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "problem_discovery_red_team_verdicts" do
    field :verdict, Ecto.Enum,
      values: [:keep_productizable, :keep_service_only, :watch, :kill]

    field :kill_argument, :string
    field :cheapest_kill_test, :string

    belongs_to :candidate, Candidate

    timestamps(type: :utc_datetime)
  end

  @required_fields [:candidate_id, :verdict, :kill_argument, :cheapest_kill_test]

  @doc """
  Changeset for creating or replacing a RedTeamVerdict on a Candidate.

  All fields are required — a prosecution without a kill_argument and a
  cheapest_kill_test isn't a prosecution, it's a hedge.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(verdict_struct, attrs) do
    verdict_struct
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_length(:kill_argument, min: 1, max: 4096)
    |> validate_length(:cheapest_kill_test, min: 1, max: 1024)
    |> unique_constraint(:candidate_id)
    |> assoc_constraint(:candidate)
  end
end
