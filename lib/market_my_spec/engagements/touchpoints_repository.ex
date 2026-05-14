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
  Returns all touchpoints for a specific thread within the account scope.

  Only returns touchpoints where both account_id and thread_id match,
  preventing cross-account data leakage.
  """
  @spec list_touchpoints_for_thread(Scope.t(), term()) :: [Touchpoint.t()]
  def list_touchpoints_for_thread(%Scope{active_account_id: account_id}, thread_id) do
    from(t in Touchpoint,
      where: t.account_id == ^account_id and t.thread_id == ^thread_id,
      order_by: [desc: t.posted_at]
    )
    |> Repo.all()
  end
end
