defmodule MarketMySpec.Engagements.SavedSearch do
  @moduledoc """
  Account-scoped saved-search record.

  A saved search captures a named query the engagement-finder can run on
  demand. The query is stored as a single Google-style string supporting
  quoted phrases, AND/OR operators, and negation — the search orchestrator
  parses operators at run time.

  Venue targeting is expressed two ways:

  - **Explicit venues** — many-to-many association with `Venue` records via
    `SavedSearchVenue`. Venue ownership is validated at the join layer
    (the join row carries `account_id` and matches both the SavedSearch
    and the Venue accounts).
  - **Source wildcards** — a list of source atoms in `source_wildcards`
    (`[:reddit, :elixirforum]`); each entry expands at run time to every
    enabled venue of that source on the account.

  At least one selector must be present — either at least one linked venue
  or at least one source wildcard. The changeset enforces this against the
  attrs map (`:venue_ids` or `:source_wildcards`) before insert/update.

  No run history is persisted; this schema is a recipe only.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Engagements.SavedSearchVenue
  alias MarketMySpec.Engagements.Venue

  @type source :: :reddit | :elixirforum

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          query: String.t() | nil,
          source_wildcards: [source()] | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          saved_search_venues: [SavedSearchVenue.t()] | Ecto.Association.NotLoaded.t(),
          venues: [Venue.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "saved_searches" do
    field :name, :string
    field :query, :string
    field :source_wildcards, {:array, Ecto.Enum},
      values: [:reddit, :elixirforum],
      default: []

    belongs_to :account, Account, type: :binary_id

    has_many :saved_search_venues, SavedSearchVenue
    many_to_many :venues, Venue, join_through: SavedSearchVenue

    timestamps()
  end

  @required_fields [:account_id, :name, :query]
  @optional_fields [:source_wildcards]

  @doc """
  Changeset for creating or updating a SavedSearch.

  Required fields: `account_id`, `name`, `query`.
  Optional fields: `source_wildcards`.

  The caller-passed `:venue_ids` list is not cast onto the schema — the
  repository validates ownership and inserts join rows directly. The
  changeset only validates the schema fields; the repository validates
  the "at least one selector" rule (venues + wildcards) at the
  call-site, since venue_ids are persisted separately from the schema
  cast.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(saved_search, attrs) do
    saved_search
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:query, min: 1, max: 2048)
    |> unique_constraint(:name, name: :saved_searches_account_id_name_index)
    |> assoc_constraint(:account)
  end
end
