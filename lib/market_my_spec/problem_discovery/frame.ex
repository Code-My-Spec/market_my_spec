defmodule MarketMySpec.ProblemDiscovery.Frame do
  @moduledoc """
  Founder-authored Frame artifact — the root of a per-Frame artifact graph.

  Carries the description of the hypothesis, the list of saved searches
  (source + query) that Gather will execute, the typed `money_gate`
  threshold that Score applies, and the structured `kill_condition` the
  founder commits to before running the pipeline (story 742).

  Every downstream artifact (JobPosting, Candidate, PaidJobSignal,
  RedTeamVerdict) belongs_to a Frame.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type saved_search :: %{source: String.t(), query: String.t()}
  @type money_gate :: %{total_spent_min: integer(), hire_rate_min: integer()}
  @type kill_condition :: %{min_money_gated_candidates: integer()}

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          description: String.t() | nil,
          saved_searches: [saved_search()] | nil,
          money_gate: money_gate() | nil,
          kill_condition: kill_condition() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "problem_discovery_frames" do
    field :description, :string
    field :saved_searches, {:array, :map}, default: []
    field :money_gate, :map
    field :kill_condition, :map

    belongs_to :account, Account

    timestamps(type: :utc_datetime)
  end

  @required_fields [:account_id, :description, :saved_searches, :money_gate, :kill_condition]

  @doc """
  Changeset for creating or updating a Frame.

  Validates that `saved_searches` is non-empty, that each saved-search entry
  has a `source` and `query`, that `money_gate` carries `total_spent_min`
  and `hire_rate_min`, and that `kill_condition` carries
  `min_money_gated_candidates`. The founder commits to all of these
  pre-pipeline; the model never sets them.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(frame, attrs) do
    frame
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_saved_searches()
    |> validate_money_gate()
    |> validate_kill_condition()
    |> assoc_constraint(:account)
  end

  defp validate_saved_searches(changeset) do
    case get_field(changeset, :saved_searches) do
      [_ | _] = searches ->
        if Enum.all?(searches, &valid_saved_search?/1) do
          changeset
        else
          add_error(changeset, :saved_searches, "each entry must have :source and :query")
        end

      _ ->
        add_error(changeset, :saved_searches, "at least one saved search is required")
    end
  end

  defp valid_saved_search?(%{source: source, query: query})
       when is_binary(source) and is_binary(query),
       do: byte_size(source) > 0 and byte_size(query) > 0

  defp valid_saved_search?(%{"source" => source, "query" => query})
       when is_binary(source) and is_binary(query),
       do: byte_size(source) > 0 and byte_size(query) > 0

  defp valid_saved_search?(_), do: false

  defp validate_money_gate(changeset) do
    case get_field(changeset, :money_gate) do
      %{total_spent_min: t, hire_rate_min: h} when is_integer(t) and is_integer(h) ->
        validate_money_gate_positive(changeset, t, h)

      %{"total_spent_min" => t, "hire_rate_min" => h} when is_integer(t) and is_integer(h) ->
        validate_money_gate_positive(changeset, t, h)

      _ ->
        add_error(
          changeset,
          :money_gate,
          "must include :total_spent_min and :hire_rate_min as integers"
        )
    end
  end

  defp validate_money_gate_positive(changeset, t, h) when t > 0 and h > 0, do: changeset

  defp validate_money_gate_positive(changeset, _t, _h),
    do:
      add_error(
        changeset,
        :money_gate,
        ":total_spent_min and :hire_rate_min must both be positive integers (zero or negative is a degenerate gate with no filtering effect)"
      )

  defp validate_kill_condition(changeset) do
    case get_field(changeset, :kill_condition) do
      %{min_money_gated_candidates: n} when is_integer(n) and n > 0 ->
        changeset

      %{"min_money_gated_candidates" => n} when is_integer(n) and n > 0 ->
        changeset

      _ ->
        add_error(
          changeset,
          :kill_condition,
          "must include :min_money_gated_candidates as a positive integer"
        )
    end
  end
end
