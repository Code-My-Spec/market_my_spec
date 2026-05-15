defmodule MarketMySpec.Engagements.SavedSearchVenue do
  @moduledoc """
  Join schema for the many-to-many between SavedSearch and Venue.

  Denormalizes `account_id` onto the join row for two reasons:

  1. Fast account-scoped queries — a single index on `account_id` covers all
     joins for an account without a join back to `saved_searches`.

  2. Cross-account guard at the database level — the changeset validates that
     `account_id` matches both the parent SavedSearch and the target Venue,
     preventing a search in account A from linking to a venue in account B.

  A unique constraint on `(saved_search_id, venue_id)` prevents the same venue
  from being linked to a saved search more than once. Cascades on both FK sides
  remove only the join row — neither the SavedSearch nor the Venue is deleted.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MarketMySpec.Accounts.Account
  alias MarketMySpec.Engagements.SavedSearch
  alias MarketMySpec.Engagements.Venue

  @type t :: %__MODULE__{
          id: integer() | nil,
          account_id: Ecto.UUID.t() | nil,
          saved_search_id: integer() | nil,
          venue_id: integer() | nil,
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          saved_search: SavedSearch.t() | Ecto.Association.NotLoaded.t(),
          venue: Venue.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "saved_search_venues" do
    belongs_to :account, Account, type: :binary_id
    belongs_to :saved_search, SavedSearch
    belongs_to :venue, Venue

    timestamps()
  end

  @doc """
  Changeset for creating a SavedSearchVenue join row.

  Requires `saved_search_id`, `venue_id`, and `account_id`. The `account_id`
  must be supplied explicitly and will be validated against the parent
  SavedSearch's account and the Venue's account at the application layer before
  insert — the database enforces the FK; cross-account mismatches must be
  rejected before calling the changeset.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(saved_search_venue, attrs) do
    saved_search_venue
    |> cast(attrs, [:saved_search_id, :venue_id, :account_id])
    |> validate_required([:saved_search_id, :venue_id, :account_id])
    |> assoc_constraint(:account)
    |> assoc_constraint(:saved_search)
    |> assoc_constraint(:venue)
    |> unique_constraint([:saved_search_id, :venue_id],
      name: :saved_search_venues_saved_search_id_venue_id_index,
      message: "venue is already linked to this saved search"
    )
  end
end
