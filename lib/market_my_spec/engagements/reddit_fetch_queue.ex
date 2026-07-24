defmodule MarketMySpec.Engagements.RedditFetchQueue do
  @moduledoc """
  Persistence for queued Reddit fetches.

  Reddit's ~1-request-per-60s-per-IP budget means a search can't fetch
  inline, so this is the seam between the two halves of a search:

    * `enqueue_search/4` records the work and returns immediately.
    * `Drain` pulls jobs one at a time, dispatches them to the paired
      agent, and calls `complete/3` with the normalized candidates.
    * `latest_completed_search/3` serves those candidates back to
      `Engagements.Search` on the next call, with no network involved.

  Enqueueing is idempotent per unit of work: a partial unique index keeps
  at most one *pending* job per (account, venue, query, cursor, thread),
  so re-running a search while its fetches are still queued refreshes the
  timestamp rather than deepening the queue.

  The queue is DB-backed rather than in-memory so a deploy or crash
  doesn't silently drop queued work — at 1/min, losing a queue is
  minutes of throughput.
  """

  import Ecto.Query, warn: false

  alias MarketMySpec.Engagements.RedditFetchJob
  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.Venue
  alias MarketMySpec.Repo
  alias MarketMySpec.Users.Scope

  @doc """
  Enqueues a search fetch for `venue` + `query`, or refreshes the existing
  pending job for that work.

  Returns `{:ok, job}`. The `:already_queued?` flag on the returned tuple
  is intentionally not exposed — callers should read queue depth via
  `pending_count/1` instead of inferring it from one enqueue.
  """
  @spec enqueue_search(Scope.t(), Venue.t(), String.t(), keyword()) ::
          {:ok, RedditFetchJob.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_search(%Scope{} = scope, %Venue{} = venue, query, opts \\ []) do
    cursor = Keyword.get(opts, :cursor) || ""
    request = Reddit.build_search_request(venue, query, cursor: cursor)

    upsert_pending(%{
      account_id: scope.active_account_id,
      user_id: scope.user.id,
      venue_id: venue.id,
      kind: :search,
      query: query,
      cursor: cursor,
      source_thread_id: "",
      request: request,
      status: :pending,
      enqueued_at: now()
    })
  end

  @doc """
  Enqueues a deep-read fetch of one thread's comment feed.
  """
  @spec enqueue_thread(Scope.t(), Venue.t() | nil, String.t(), keyword()) ::
          {:ok, RedditFetchJob.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_thread(%Scope{} = scope, venue, source_thread_id, opts \\ []) do
    request = Reddit.build_thread_request(source_thread_id, opts)

    upsert_pending(%{
      account_id: scope.active_account_id,
      user_id: scope.user.id,
      venue_id: venue && venue.id,
      kind: :thread,
      query: "",
      cursor: "",
      source_thread_id: source_thread_id,
      request: request,
      status: :pending,
      enqueued_at: now()
    })
  end

  # ON CONFLICT against the partial unique index: an identical pending job is
  # left in place rather than raising or duplicating.
  #
  # Crucially this does NOT touch `enqueued_at`. `claim_next/0` orders by it,
  # so bumping it on every re-request moved the job to the BACK of the queue —
  # and since "check whether my results arrived" means re-running the search,
  # a job could be starved indefinitely by the very act of waiting for it.
  # Observed live: a queue drained 8 → 4 while one job sat at position last the
  # whole time. The request's place in line is set by when it was FIRST asked
  # for.
  defp upsert_pending(attrs) do
    %RedditFetchJob{}
    |> RedditFetchJob.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [updated_at: now()]],
      conflict_target: {:unsafe_fragment, ~s<(account_id, venue_id, query, cursor, source_thread_id) WHERE status = 'pending'>},
      returning: true
    )
  end

  @doc """
  Claims the oldest pending job and marks it `running`.

  Returns `{:ok, job}` or `:empty`. The claim is a single conditional
  UPDATE, so two drain processes (a rolling deploy overlapping old and new
  containers) can't hand the same job to the agent twice.
  """
  @spec claim_next() :: {:ok, RedditFetchJob.t()} | :empty
  def claim_next do
    subquery =
      from j in RedditFetchJob,
        where: j.status == :pending,
        order_by: [asc: j.enqueued_at, asc: j.id],
        limit: 1,
        select: j.id

    query =
      from j in RedditFetchJob,
        where: j.id in subquery(subquery) and j.status == :pending,
        select: j

    case Repo.update_all(query,
           set: [status: :running, started_at: now(), updated_at: now()],
           inc: [attempts: 1]
         ) do
      {1, [job]} -> {:ok, Repo.preload(job, [:venue, :user])}
      _ -> :empty
    end
  end

  @doc """
  Claims one specific pending job by id, marking it `running`.

  Same conditional-UPDATE semantics as `claim_next/0` — returns `:empty` if
  the job is already claimed or gone. Used where the caller has a particular
  job in hand (an operator retrying one venue, and spex that must not race
  the global queue).
  """
  @spec claim(integer()) :: {:ok, RedditFetchJob.t()} | :empty
  def claim(job_id) do
    query =
      from j in RedditFetchJob,
        where: j.id == ^job_id and j.status == :pending,
        select: j

    case Repo.update_all(query,
           set: [status: :running, started_at: now(), updated_at: now()],
           inc: [attempts: 1]
         ) do
      {1, [job]} -> {:ok, Repo.preload(job, [:venue, :user])}
      _ -> :empty
    end
  end

  @doc """
  Marks a job done and stores the normalized result for the read path.
  """
  @spec complete(RedditFetchJob.t(), [map()], String.t() | nil) ::
          {:ok, RedditFetchJob.t()} | {:error, Ecto.Changeset.t()}
  def complete(%RedditFetchJob{} = job, candidates, next_cursor) do
    job
    |> RedditFetchJob.changeset(%{
      status: :done,
      candidates: candidates,
      next_cursor: next_cursor,
      last_error: nil,
      completed_at: now()
    })
    |> Repo.update()
  end

  @doc """
  Marks a job failed, recording the reason.

  Terminal by design: a failed job is not retried automatically. At 1/min
  a retry loop burns the whole budget on a request that is probably
  failing for a reason retrying won't fix (a 403, a dead subreddit). The
  next search re-enqueues the work as a fresh job.
  """
  @spec fail(RedditFetchJob.t(), term()) ::
          {:ok, RedditFetchJob.t()} | {:error, Ecto.Changeset.t()}
  def fail(%RedditFetchJob{} = job, reason) do
    job
    |> RedditFetchJob.changeset(%{
      status: :failed,
      last_error: format_error(reason),
      completed_at: now()
    })
    |> Repo.update()
  end

  @doc """
  Releases a claimed job back to `pending` without counting it as a
  failure — used when the agent is offline, where the job hasn't been
  attempted at all.
  """
  @spec release(RedditFetchJob.t()) :: {:ok, RedditFetchJob.t()} | {:error, Ecto.Changeset.t()}
  def release(%RedditFetchJob{} = job) do
    job
    |> RedditFetchJob.changeset(%{status: :pending, started_at: nil, attempts: job.attempts - 1})
    |> Repo.update()
  end

  @doc """
  Returns the newest completed search job for a venue + query, or nil.

  This is what `Engagements.Search` reads instead of fetching.
  """
  @spec latest_completed_search(Scope.t(), Venue.t(), String.t()) :: RedditFetchJob.t() | nil
  def latest_completed_search(%Scope{active_account_id: account_id}, %Venue{} = venue, query) do
    Repo.one(
      from j in RedditFetchJob,
        where:
          j.account_id == ^account_id and j.venue_id == ^venue.id and
            j.query == ^query and j.kind == :search and j.status == :done,
        order_by: [desc: j.completed_at, desc: j.id],
        limit: 1
    )
  end

  @doc """
  Counts pending + running jobs for an account, optionally for one venue.
  """
  @spec pending_count(Scope.t(), Venue.t() | nil) :: non_neg_integer()
  def pending_count(%Scope{active_account_id: account_id}, venue \\ nil) do
    query =
      from j in RedditFetchJob,
        where: j.account_id == ^account_id and j.status in [:pending, :running]

    query = if venue, do: where(query, [j], j.venue_id == ^venue.id), else: query

    Repo.aggregate(query, :count, :id)
  end

  @doc """
  Returns the newest failed search job for a venue + query, or nil, so a
  search can report *why* a venue has no fresh results rather than
  silently showing stale ones.
  """
  @spec latest_failure(Scope.t(), Venue.t(), String.t()) :: RedditFetchJob.t() | nil
  def latest_failure(%Scope{active_account_id: account_id}, %Venue{} = venue, query) do
    Repo.one(
      from j in RedditFetchJob,
        where:
          j.account_id == ^account_id and j.venue_id == ^venue.id and
            j.query == ^query and j.status == :failed,
        order_by: [desc: j.completed_at, desc: j.id],
        limit: 1
    )
  end

  @doc "Lists jobs for an account, newest first. Operator/debug surface."
  @spec list_jobs(Scope.t(), keyword()) :: [RedditFetchJob.t()]
  def list_jobs(%Scope{active_account_id: account_id}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    Repo.all(
      from j in RedditFetchJob,
        where: j.account_id == ^account_id,
        order_by: [desc: j.id],
        limit: ^limit,
        preload: [:venue]
    )
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
