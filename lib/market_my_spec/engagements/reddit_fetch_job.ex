defmodule MarketMySpec.Engagements.RedditFetchJob do
  @moduledoc """
  One queued Reddit RSS fetch, to be executed by the user's paired agent.

  Reddit meters ~1 request per 60s per IP, so fetches can't run inline with
  a search. A job is the unit the drain worker paces: it carries the request
  map built by `Engagements.Source.Reddit`, and on success it carries back
  the normalized candidates so `Engagements.Search` can serve results
  without touching the network.

  `query`, `cursor`, and `source_thread_id` default to `""` rather than
  `nil` — they form the identity of a unit of work, and the partial unique
  index that keeps duplicate pending jobs out of the queue can't dedupe on
  NULLs.

  Statuses: `pending` → `running` → `done` | `failed`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type status :: :pending | :running | :done | :failed
  @type kind :: :search | :thread

  @statuses [:pending, :running, :done, :failed]
  @kinds [:search, :thread]

  schema "reddit_fetch_jobs" do
    field :kind, Ecto.Enum, values: @kinds
    field :query, :string, default: ""
    field :cursor, :string, default: ""
    field :source_thread_id, :string, default: ""
    field :request, :map, default: %{}

    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :attempts, :integer, default: 0
    field :last_error, :string

    field :candidates, {:array, :map}
    field :next_cursor, :string

    field :enqueued_at, :utc_datetime
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :account, MarketMySpec.Accounts.Account, type: :binary_id
    belongs_to :user, MarketMySpec.Users.User
    belongs_to :venue, MarketMySpec.Engagements.Venue

    timestamps(type: :utc_datetime)
  end

  @required [:account_id, :user_id, :kind, :request, :enqueued_at]
  @optional [
    :venue_id,
    :query,
    :cursor,
    :source_thread_id,
    :status,
    :attempts,
    :last_error,
    :candidates,
    :next_cursor,
    :started_at,
    :completed_at
  ]

  @doc "Changeset for enqueueing and for drain-worker state transitions."
  @spec changeset(t :: %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(job, attrs) do
    job
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> update_change(:query, &blank_to_empty/1)
    |> update_change(:cursor, &blank_to_empty/1)
    |> update_change(:source_thread_id, &blank_to_empty/1)
    |> assoc_constraint(:account)
    |> assoc_constraint(:user)
    |> assoc_constraint(:venue)
  end

  defp blank_to_empty(nil), do: ""
  defp blank_to_empty(value), do: value

  @doc "Statuses a job can be in."
  def statuses, do: @statuses
end
