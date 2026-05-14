defmodule MarketMySpec.Engagements.VenuesRepository do
  @moduledoc """
  Account-scoped persistence for Venue records.

  All queries are filtered by the current scope's active_account_id.
  Cross-account access returns empty results or :not_found rather than
  raising or leaking data.

  Venue identifiers are validated against the appropriate Source adapter
  before any insert or update is persisted.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  @doc """
  Returns all venues for the account in the given scope.

  Accepts an optional `source` atom to filter results to a single source
  (e.g. `:reddit` or `:elixirforum`). With no filter, all venues for the
  account are returned ordered by insertion time ascending.
  """
  @spec list_venues(Scope.t(), Venue.source() | nil) :: [Venue.t()]
  def list_venues(%Scope{active_account_id: account_id}, source \\ nil) do
    base = from(v in Venue, where: v.account_id == ^account_id, order_by: [asc: v.inserted_at])

    base
    |> maybe_filter_source(source)
    |> Repo.all()
  end

  @doc """
  Fetches a single venue by id scoped to the account in the given scope.

  Returns `{:ok, venue}` when found, or `{:error, :not_found}` when the
  venue does not exist or belongs to a different account.
  """
  @spec get_venue(Scope.t(), integer()) :: {:ok, Venue.t()} | {:error, :not_found}
  def get_venue(%Scope{active_account_id: account_id}, id) do
    case Repo.one(from(v in Venue, where: v.id == ^id and v.account_id == ^account_id)) do
      nil -> {:error, :not_found}
      venue -> {:ok, venue}
    end
  end

  @doc """
  Persists a new Venue record for the account in the given scope.

  The `account_id` in attrs is overridden by `scope.active_account_id`
  to enforce account scoping. The identifier is validated against the
  appropriate Source adapter before insert.

  Returns `{:ok, venue}` on success, `{:error, changeset}` on failure.
  """
  @spec create_venue(Scope.t(), map()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  def create_venue(%Scope{active_account_id: account_id}, attrs) do
    scoped_attrs = Map.put(attrs, :account_id, account_id)

    %Venue{}
    |> Venue.changeset(scoped_attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing Venue record scoped to the account in the given scope.

  Returns `{:ok, venue}` on success, `{:error, :not_found}` when the venue
  does not exist or belongs to a different account, or `{:error, changeset}`
  on validation failure.
  """
  @spec update_venue(Scope.t(), integer(), map()) ::
          {:ok, Venue.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_venue(%Scope{} = scope, id, attrs) do
    with {:ok, venue} <- get_venue(scope, id) do
      venue
      |> Venue.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Deletes a Venue record scoped to the account in the given scope.

  Returns `{:ok, venue}` on success, or `{:error, :not_found}` when the
  venue does not exist or belongs to a different account.
  """
  @spec delete_venue(Scope.t(), integer()) :: {:ok, Venue.t()} | {:error, :not_found}
  def delete_venue(%Scope{} = scope, id) do
    with {:ok, venue} <- get_venue(scope, id) do
      Repo.delete(venue)
    end
  end

  defp maybe_filter_source(query, nil), do: query
  defp maybe_filter_source(query, source), do: where(query, [v], v.source == ^source)
end
