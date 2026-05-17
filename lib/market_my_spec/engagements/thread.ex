defmodule MarketMySpec.Engagements.Thread do
  @moduledoc """
  Ingested thread record. Account-scoped.

  Stores the normalized OP + comment tree alongside the raw platform payload.
  Repeat fetches within a freshness window read this row instead of re-hitting
  the source platform API.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type source :: :reddit | :elixirforum

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          account_id: Ecto.UUID.t() | nil,
          source: source(),
          source_thread_id: String.t() | nil,
          url: String.t() | nil,
          title: String.t() | nil,
          op_body: String.t() | nil,
          comment_tree: map() | nil,
          raw_payload: map() | nil,
          fetched_at: DateTime.t() | nil,
          last_activity_at: DateTime.t() | nil,
          account: MarketMySpec.Accounts.Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "threads" do
    field :source, Ecto.Enum, values: [:reddit, :elixirforum]
    field :source_thread_id, :string
    field :url, :string
    field :title, :string
    field :op_body, :string
    field :comment_tree, :map, default: %{}
    field :raw_payload, :map, default: %{}
    field :fetched_at, :utc_datetime
    field :last_activity_at, :utc_datetime

    belongs_to :account, MarketMySpec.Accounts.Account, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @required_fields [:account_id, :source, :source_thread_id, :url, :title]
  @optional_fields [:fetched_at, :op_body, :comment_tree, :raw_payload, :last_activity_at]

  @doc """
  Changeset for creating or updating a Thread record.

  Required fields: account_id, source, source_thread_id, url, title.
  Optional fields: fetched_at, op_body, comment_tree, raw_payload, last_activity_at.

  `fetched_at` is nullable — search-time upserts (`upsert_from_search/3`) do not
  set it. It is populated by deep-read flows (story 706) when the full thread
  content is fetched from the source platform.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(thread, attrs) do
    thread
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:source_thread_id, min: 1, max: 255)
    |> validate_length(:url, min: 1, max: 2048)
    |> validate_length(:title, min: 1, max: 500)
    |> assoc_constraint(:account)
    |> unique_constraint(:source_thread_id,
      name: :threads_account_id_source_source_thread_id_index,
      message: "has already been taken"
    )
  end
end
