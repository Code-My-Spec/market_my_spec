defmodule MarketMySpec.Engagements.ThreadsRepository do
  @moduledoc """
  Account-scoped thread persistence with a freshness-window cache.

  Threads are cached per (account, source, source_thread_id). A cached thread
  is considered fresh when its `fetched_at` is within the freshness TTL.
  Stale or missing threads are fetched from the source adapter, persisted
  (insert or update), and returned.

  ## Freshness TTL

  The freshness window is 1 hour (3 600 seconds). Threads fetched within that
  window are served from the database without hitting the platform API again.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Engagements.Source.ElixirForum
  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Thread
  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  @freshness_ttl_seconds 3_600

  @doc """
  Returns the cached Thread for the given (scope, venue, thread_id) tuple when
  it is within the freshness window; otherwise fetches from the source adapter,
  persists the result, and returns it.

  Account scoping is enforced: only threads belonging to `scope.active_account_id`
  are considered. Returns `{:ok, thread}` on success or `{:error, reason}` on
  failure (including adapter errors).
  """
  @spec get_or_fetch_thread(Scope.t(), Venue.t(), String.t()) ::
          {:ok, Thread.t()} | {:error, term()}
  def get_or_fetch_thread(%Scope{active_account_id: account_id}, %Venue{} = venue, thread_id)
      when is_binary(thread_id) do
    case find_fresh_thread(account_id, venue.source, thread_id) do
      %Thread{} = thread -> {:ok, thread}
      nil -> fetch_and_persist(account_id, venue, thread_id)
    end
  end

  @doc """
  Returns the Thread by its UUID id, scoped to the account.

  Returns `{:ok, thread}` when found, `{:error, :not_found}` when missing
  or belonging to a different account.
  """
  @spec get_thread_by_id(Scope.t(), Ecto.UUID.t()) :: {:ok, Thread.t()} | {:error, :not_found}
  def get_thread_by_id(%Scope{active_account_id: account_id}, thread_id)
      when is_binary(thread_id) do
    case Repo.get_by(Thread, id: thread_id, account_id: account_id) do
      %Thread{} = thread -> {:ok, thread}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Returns all threads fetched for the account in the given scope, ordered by
  `fetched_at` descending (most recently fetched first).
  """
  @spec list_threads(Scope.t()) :: [Thread.t()]
  def list_threads(%Scope{active_account_id: account_id}) do
    from(t in Thread,
      where: t.account_id == ^account_id,
      order_by: [desc: t.fetched_at]
    )
    |> Repo.all()
  end

  # Private helpers

  defp find_fresh_thread(account_id, source, thread_id) do
    freshness_cutoff = DateTime.add(DateTime.utc_now(:second), -@freshness_ttl_seconds, :second)

    from(t in Thread,
      where:
        t.account_id == ^account_id and
          t.source == ^source and
          t.source_thread_id == ^thread_id and
          t.fetched_at >= ^freshness_cutoff
    )
    |> Repo.one()
  end

  defp fetch_and_persist(account_id, venue, thread_id) do
    adapter = adapter_for(venue.source)

    with {:ok, raw_map} <- adapter.get_thread(venue, thread_id),
         {:ok, thread} <- upsert_thread(account_id, venue.source, thread_id, raw_map) do
      {:ok, thread}
    end
  end

  defp adapter_for(:reddit), do: Reddit
  defp adapter_for(:elixirforum), do: ElixirForum

  defp upsert_thread(account_id, source, thread_id, raw_map) do
    now = DateTime.utc_now(:second)

    attrs =
      raw_map
      |> normalize_map(account_id, source, thread_id, now)

    changeset = Thread.changeset(%Thread{}, attrs)

    Repo.insert(changeset,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: [:account_id, :source, :source_thread_id],
      returning: true
    )
  end

  defp normalize_map(raw_map, account_id, source, thread_id, fetched_at) do
    %{
      account_id: account_id,
      source: source,
      source_thread_id: thread_id,
      url: Map.get(raw_map, :url, default_url(source, thread_id)),
      title: Map.get(raw_map, :title, "Thread #{thread_id}"),
      op_body: Map.get(raw_map, :op_body, Map.get(raw_map, :body, "")),
      comment_tree: Map.get(raw_map, :comment_tree, %{}),
      raw_payload: raw_map,
      fetched_at: fetched_at
    }
  end

  defp default_url(:reddit, thread_id),
    do: "https://www.reddit.com/comments/#{thread_id}/"

  defp default_url(:elixirforum, thread_id),
    do: "https://elixirforum.com/t/thread/#{thread_id}"
end
