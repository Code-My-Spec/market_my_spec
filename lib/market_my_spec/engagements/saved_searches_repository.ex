defmodule MarketMySpec.Engagements.SavedSearchesRepository do
  @moduledoc """
  Account-scoped CRUD for SavedSearch records.

  All queries filter on the current scope's `active_account_id`. Cross-account
  access returns `:not_found` rather than raising or leaking data.

  `run_saved_search/2` resolves a saved-search recipe to a concrete venue list
  — the linked venues (many-to-many) plus wildcard-expanded enabled venues per
  source — then delegates to `Engagements.Search.search/3`.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Engagements.SavedSearch
  alias MarketMySpec.Engagements.SavedSearchVenue
  alias MarketMySpec.Engagements.Search
  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Engagements.VenuesRepository
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  @type search_result :: %{
          candidates: [map()],
          failures: [%{venue: map() | nil, reason: term()}]
        }

  @doc """
  Returns all saved searches for the caller's account, preloaded with their
  linked venues, ordered by insertion time ascending.
  """
  @spec list_saved_searches(Scope.t()) :: [SavedSearch.t()]
  def list_saved_searches(%Scope{active_account_id: account_id}) do
    from(s in SavedSearch,
      where: s.account_id == ^account_id,
      order_by: [asc: s.inserted_at],
      preload: [:venues]
    )
    |> Repo.all()
  end

  @doc """
  Fetches a single saved search by id (account-scoped), preloaded with venues.

  Returns `{:ok, saved_search}` or `{:error, :not_found}` on missing or
  cross-account access.
  """
  @spec get_saved_search(Scope.t(), integer()) ::
          {:ok, SavedSearch.t()} | {:error, :not_found}
  def get_saved_search(%Scope{active_account_id: account_id}, id) do
    query =
      from(s in SavedSearch,
        where: s.id == ^id and s.account_id == ^account_id,
        preload: [:venues]
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      saved_search -> {:ok, saved_search}
    end
  end

  @doc """
  Persists a new SavedSearch.

  `attrs` must include `name` and `query` (a single Google-style query
  string). At least one venue selector must be present — either
  `:venue_ids` (a non-empty list of Venue ids that all belong to the
  caller's account) or `:source_wildcards` (a non-empty list of source
  atoms). Both may be provided.

  Returns `{:ok, saved_search}` or `{:error, changeset}`.
  """
  @spec create_saved_search(Scope.t(), map()) ::
          {:ok, SavedSearch.t()} | {:error, Ecto.Changeset.t()}
  def create_saved_search(%Scope{active_account_id: account_id} = scope, attrs) do
    venue_ids = extract_venue_ids(attrs)
    wildcards = Map.get(attrs, :source_wildcards) || Map.get(attrs, "source_wildcards") || []

    with {:ok, _} <- validate_at_least_one_selector(venue_ids, wildcards),
         {:ok, _} <- validate_venue_ids_belong_to_account(scope, venue_ids) do
      scoped_attrs =
        attrs
        |> Map.put(:account_id, account_id)
        |> Map.put(:source_wildcards, wildcards)

      Repo.transaction(fn ->
        case %SavedSearch{} |> SavedSearch.changeset(scoped_attrs) |> Repo.insert() do
          {:ok, saved_search} ->
            :ok = insert_venue_joins(saved_search, account_id, venue_ids)
            Repo.preload(saved_search, :venues, force: true)

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end
  end

  @doc """
  Updates an existing SavedSearch (account-scoped).

  Accepts the same optional keys as `create_saved_search/2`. When
  `:venue_ids` is present, the join rows are replaced atomically with
  ownership re-validated. When absent, the existing venue selection is
  preserved.
  """
  @spec update_saved_search(Scope.t(), integer(), map()) ::
          {:ok, SavedSearch.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_saved_search(%Scope{active_account_id: account_id} = scope, id, attrs) do
    with {:ok, saved_search} <- get_saved_search(scope, id) do
      Repo.transaction(fn ->
        do_update(scope, account_id, saved_search, attrs)
      end)
    end
  end

  defp do_update(scope, account_id, saved_search, attrs) do
    case Map.fetch(attrs, :venue_ids) do
      :error ->
        update_without_venue_change(saved_search, attrs)

      {:ok, venue_ids} ->
        wildcards =
          Map.get(attrs, :source_wildcards) || saved_search.source_wildcards || []

        with {:ok, _} <- validate_at_least_one_selector(venue_ids, wildcards),
             {:ok, _} <- validate_venue_ids_belong_to_account(scope, venue_ids),
             {:ok, updated} <- update_changeset(saved_search, attrs) do
          replace_venue_joins(updated, account_id, venue_ids)
          Repo.preload(updated, :venues, force: true)
        else
          {:error, error} -> Repo.rollback(error)
        end
    end
  end

  defp update_without_venue_change(saved_search, attrs) do
    case update_changeset(saved_search, attrs) do
      {:ok, updated} -> Repo.preload(updated, :venues, force: true)
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  defp update_changeset(saved_search, attrs) do
    saved_search |> SavedSearch.changeset(attrs) |> Repo.update()
  end

  @doc """
  Deletes a SavedSearch (account-scoped). Cascade only touches the join
  rows; linked venues stay.
  """
  @spec delete_saved_search(Scope.t(), integer()) ::
          {:ok, SavedSearch.t()} | {:error, :not_found}
  def delete_saved_search(%Scope{} = scope, id) do
    with {:ok, saved_search} <- get_saved_search(scope, id) do
      Repo.delete(saved_search)
    end
  end

  @doc """
  Runs a saved search: resolves the recipe (linked venues + wildcard-expanded
  enabled venues per source), deduplicates by venue id, and delegates to
  `Engagements.Search.search/3` with the saved query string.

  A saved search with zero resolved venues returns
  `%{candidates: [], failures: []}` — empty, not an error.
  """
  @spec run_saved_search(Scope.t(), integer()) ::
          {:ok, search_result()} | {:error, :not_found}
  def run_saved_search(%Scope{} = scope, id) do
    with {:ok, saved_search} <- get_saved_search(scope, id) do
      venues = resolve_venues(scope, saved_search)
      result = fan_out_search(scope, saved_search.query, venues)
      {:ok, result}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp extract_venue_ids(attrs) do
    Map.get(attrs, :venue_ids) || Map.get(attrs, "venue_ids") || []
  end

  defp validate_at_least_one_selector([], []) do
    changeset =
      %SavedSearch{}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(
        :venue_ids,
        "must have at least one linked venue or at least one source wildcard"
      )

    {:error, changeset}
  end

  defp validate_at_least_one_selector(_venue_ids, _wildcards), do: {:ok, :selector_present}

  defp validate_venue_ids_belong_to_account(_scope, []), do: {:ok, :no_venues}

  defp validate_venue_ids_belong_to_account(%Scope{active_account_id: account_id}, venue_ids) do
    count =
      from(v in Venue,
        where: v.id in ^venue_ids and v.account_id == ^account_id,
        select: count(v.id)
      )
      |> Repo.one()

    if count == length(venue_ids) do
      {:ok, :all_venues_owned}
    else
      changeset =
        %SavedSearch{}
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(
          :venue_ids,
          "one or more venue ids do not belong to this account"
        )

      {:error, changeset}
    end
  end

  defp insert_venue_joins(_saved_search, _account_id, []), do: :ok

  defp insert_venue_joins(saved_search, account_id, venue_ids) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    rows =
      Enum.map(venue_ids, fn venue_id ->
        %{
          saved_search_id: saved_search.id,
          venue_id: venue_id,
          account_id: account_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    {_inserted, _} = Repo.insert_all(SavedSearchVenue, rows)
    :ok
  end

  defp replace_venue_joins(saved_search, account_id, venue_ids) do
    Repo.delete_all(
      from(j in SavedSearchVenue, where: j.saved_search_id == ^saved_search.id)
    )

    insert_venue_joins(saved_search, account_id, venue_ids)
  end

  defp resolve_venues(%Scope{} = scope, saved_search) do
    linked = saved_search.venues || []

    wildcard_venues =
      (saved_search.source_wildcards || [])
      |> Enum.flat_map(fn source -> VenuesRepository.list_venues(scope, source) end)
      |> Enum.filter(& &1.enabled)

    (linked ++ wildcard_venues)
    |> Enum.filter(& &1.enabled)
    |> Enum.uniq_by(& &1.id)
  end

  defp fan_out_search(_scope, _query, []), do: %{candidates: [], failures: []}

  defp fan_out_search(_scope, nil, _venues), do: %{candidates: [], failures: []}

  defp fan_out_search(_scope, "", _venues), do: %{candidates: [], failures: []}

  defp fan_out_search(scope, query, venues) when is_binary(query) do
    venues
    |> Task.async_stream(
      fn venue ->
        {venue, Search.search(scope, query, venue: venue.identifier)}
      end,
      on_timeout: :kill_task,
      timeout: 15_000
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {_venue, %{candidates: candidates, failures: failures}}},
      {acc_candidates, acc_failures} ->
        {acc_candidates ++ candidates, acc_failures ++ failures}

      {:exit, reason}, {acc_candidates, acc_failures} ->
        {acc_candidates, acc_failures ++ [%{venue: nil, reason: {:task_exit, reason}}]}
    end)
    |> then(fn {candidates, failures} ->
      ranked =
        candidates
        |> Enum.uniq_by(fn c -> Map.get(c, "url") || Map.get(c, :url) end)
        |> Enum.sort_by(fn c -> Map.get(c, "rank", 0) end, :desc)

      %{candidates: ranked, failures: failures}
    end)
  end
end
