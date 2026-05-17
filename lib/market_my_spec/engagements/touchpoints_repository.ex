defmodule MarketMySpec.Engagements.TouchpointsRepository do
  @moduledoc """
  Account-scoped persistence for Touchpoint records.

  All queries are filtered by the current scope's active_account_id.
  Cross-account access returns empty results or :not_found rather than
  raising or leaking data.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Engagements.Touchpoint
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  @doc """
  Fetches a Touchpoint by id, scoped to the account.

  Returns `{:ok, touchpoint}` or `{:error, :not_found}`. Cross-account
  access (id belongs to a different account) returns :not_found.
  """
  @spec get_touchpoint_by_id(Scope.t(), term()) ::
          {:ok, Touchpoint.t()} | {:error, :not_found}
  def get_touchpoint_by_id(%Scope{active_account_id: account_id}, touchpoint_id) do
    case Repo.get_by(Touchpoint, id: touchpoint_id, account_id: account_id) do
      nil -> {:error, :not_found}
      tp -> {:ok, tp}
    end
  end

  @doc """
  Updates an existing Touchpoint's state (and optionally comment_url / posted_at).

  Returns `{:ok, touchpoint}` on success, `{:error, changeset}` on validation failure,
  or `{:error, :not_found}` when the touchpoint doesn't belong to the scope's account.
  """
  @spec update_touchpoint(Scope.t(), term(), map()) ::
          {:ok, Touchpoint.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def update_touchpoint(%Scope{} = scope, touchpoint_id, attrs) do
    case get_touchpoint_by_id(scope, touchpoint_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, touchpoint} ->
        touchpoint
        |> Touchpoint.update_changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Hard-deletes a Touchpoint scoped to the account.

  Returns `{:ok, touchpoint}` on success or `{:error, :not_found}` when the
  touchpoint doesn't belong to the scope's account.
  """
  @spec delete_touchpoint(Scope.t(), term()) ::
          {:ok, Touchpoint.t()} | {:error, :not_found}
  def delete_touchpoint(%Scope{} = scope, touchpoint_id) do
    case get_touchpoint_by_id(scope, touchpoint_id) do
      {:error, :not_found} -> {:error, :not_found}
      {:ok, touchpoint} -> Repo.delete(touchpoint)
    end
  end

  @doc """
  Persists a new Touchpoint record for the account in the given scope.

  The `account_id` in attrs is overridden by `scope.active_account_id`
  to enforce account scoping.

  Returns `{:ok, touchpoint}` on success, `{:error, changeset}` on failure.
  """
  @spec create_touchpoint(Scope.t(), map()) :: {:ok, Touchpoint.t()} | {:error, Ecto.Changeset.t()}
  def create_touchpoint(%Scope{active_account_id: account_id}, attrs) do
    scoped_attrs = Map.put(attrs, :account_id, account_id)

    %Touchpoint{}
    |> Touchpoint.changeset(scoped_attrs)
    |> Repo.insert()
  end

  @doc """
  Persists a new staged Touchpoint for the account in the given scope.

  Staged touchpoints do not require `comment_url` or `posted_at` — those
  are populated later when the user submits the live comment URL.

  The `account_id` in attrs is overridden by `scope.active_account_id`
  to enforce account scoping.

  Returns `{:ok, touchpoint}` on success, `{:error, changeset}` on failure.
  """
  @spec create_staged_touchpoint(Scope.t(), map()) :: {:ok, Touchpoint.t()} | {:error, Ecto.Changeset.t()}
  def create_staged_touchpoint(%Scope{active_account_id: account_id}, attrs) do
    scoped_attrs = Map.put(attrs, :account_id, account_id)

    %Touchpoint{}
    |> Touchpoint.staged_changeset(scoped_attrs)
    |> Repo.insert()
  end

  @doc """
  Returns all touchpoints for the account in the given scope,
  ordered by posted_at descending (most recent first).
  """
  @spec list_touchpoints(Scope.t()) :: [Touchpoint.t()]
  def list_touchpoints(%Scope{active_account_id: account_id}) do
    from(t in Touchpoint,
      where: t.account_id == ^account_id,
      order_by: [desc: t.posted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns all touchpoints for the account in the given scope, ordered by
  inserted_at descending (newest first). Accepts optional filters:

    - `:state` — filter to a single state atom (`:staged`, `:posted`, `:abandoned`)
    - `:preload` — list of associations to preload (e.g. `[:thread]`)

  """
  @spec list_touchpoints(Scope.t(), keyword()) :: [Touchpoint.t()]
  def list_touchpoints(%Scope{active_account_id: account_id}, opts) when is_list(opts) do
    state_filter = Keyword.get(opts, :state)
    preloads = Keyword.get(opts, :preload, [])

    base_query =
      from(t in Touchpoint,
        where: t.account_id == ^account_id,
        order_by: [desc: t.inserted_at]
      )

    base_query
    |> apply_state_filter(state_filter)
    |> Repo.all()
    |> Repo.preload(preloads)
  end

  @doc """
  Returns all touchpoints for a specific thread within the account scope.

  Only returns touchpoints where both account_id and thread_id match,
  preventing cross-account data leakage.
  """
  @spec list_touchpoints_for_thread(Scope.t(), term()) :: [Touchpoint.t()]
  def list_touchpoints_for_thread(%Scope{active_account_id: account_id}, thread_id) do
    from(t in Touchpoint,
      where: t.account_id == ^account_id and t.thread_id == ^thread_id,
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Returns the engagement summary for a thread: count of touchpoints and
  the latest touchpoint's state, angle, and posted_at (by inserted_at desc).

  Returns a map with keys: count, latest_state, latest_angle, latest_posted_at.
  All latest_* fields are nil when count == 0.
  """
  @spec engagement_summary(Ecto.UUID.t(), Ecto.UUID.t()) :: map()
  def engagement_summary(account_id, thread_id) do
    touchpoints =
      from(t in Touchpoint,
        where: t.account_id == ^account_id and t.thread_id == ^thread_id,
        order_by: [desc: t.inserted_at]
      )
      |> Repo.all()

    count = length(touchpoints)
    latest = List.first(touchpoints)

    %{
      "count" => count,
      "latest_state" => latest && to_string_or_nil(latest.state),
      "latest_angle" => latest && latest.angle,
      "latest_posted_at" =>
        latest && latest.posted_at && DateTime.to_iso8601(latest.posted_at)
    }
  end

  defp apply_state_filter(query, nil), do: query

  defp apply_state_filter(query, state) do
    from(t in query, where: t.state == ^state)
  end

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(val), do: to_string(val)
end
