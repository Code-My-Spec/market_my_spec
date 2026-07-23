defmodule MarketMySpec.Engagements.RedditFetchQueue.Drain do
  @moduledoc """
  Pulls queued Reddit fetches one at a time and runs them through the
  owning user's paired agent.

  One job in flight, ever. The agent enforces its own serialization and
  1/min limit (`MarketMySpecAgent.Reddit.Worker`) — this process does not
  duplicate that gate, it just makes sure the server never *asks* for more
  than one thing at a time and doesn't spin when there's nothing to do.

  Normalization happens here rather than on the agent: the binary ships raw
  Atom XML back and `Reddit.normalize_search/1` parses it server-side, so
  there is one parser and a stale binary can't drift the candidate shape.

  When the user has no online agent the job is released back to `pending`
  (not failed) and the drain idles — queued work waits for the binary to
  come back rather than burning attempts against nothing. There is
  deliberately no server-side fallback fetch in production: falling back to
  the datacenter IP is the exact thing the agent exists to avoid.

  ## Configuration

      config :market_my_spec, :reddit_fetch,
        drain: :background,   # :background | :inline | :off
        transport: :agent     # :agent | :direct

  `drain: :inline` makes `kick/1` drain synchronously in the calling
  process instead of on a timer, and `transport: :direct` performs the
  fetch from this node rather than dispatching to a binary. Test uses
  both, so spex exercise the whole enqueue → fetch → normalize → persist →
  read chain against cassettes in one call. Because the direct transport
  runs the *same* `Reddit.fetch/2` on the *same* request map, cassette URL
  matching still validates request construction — the seam skips the
  socket, not the logic.
  """

  use GenServer

  require Logger

  alias MarketMySpec.Agents.Dispatcher
  alias MarketMySpec.Engagements.RedditFetchJob
  alias MarketMySpec.Engagements.RedditFetchQueue
  alias MarketMySpec.Engagements.Source.Reddit
  alias MarketMySpec.Engagements.ThreadsRepository
  alias MarketMySpec.Users.Scope

  # How often to look for work when the queue was empty last time. Well
  # under Reddit's window, because an empty poll costs nothing — the
  # pacing that matters is the agent's, not ours.
  @idle_poll_ms 5_000

  # Backoff when the agent is offline. Longer, because nothing can happen
  # until the binary reconnects and we don't want a log line every 5s.
  @offline_poll_ms 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Wakes the drain immediately — called after enqueueing.

  Under `drain: :inline` this runs the queue to empty in the calling
  process instead, so a search sees its own fetch land.
  """
  @spec kick(GenServer.server()) :: :ok
  def kick(server \\ __MODULE__) do
    case drain_mode() do
      :inline -> drain_to_empty()
      :off -> :ok
      _ -> GenServer.cast(server, :drain)
    end
  catch
    :exit, _ -> :ok
  end

  @doc """
  Claims and performs jobs until the queue is empty. Returns the number of
  jobs performed.

  Public so spex (and an operator at a console) can flush the queue without
  waiting on the timer.
  """
  @spec drain_to_empty(non_neg_integer()) :: non_neg_integer()
  def drain_to_empty(performed \\ 0) do
    case RedditFetchQueue.claim_next() do
      :empty ->
        performed

      {:ok, job} ->
        case perform(job) do
          # Offline means the job went back to pending — draining again
          # would just re-claim it forever.
          :offline -> performed
          _ -> drain_to_empty(performed + 1)
        end
    end
  end

  @impl true
  def init(opts) do
    if Keyword.get(opts, :mode, drain_mode()) == :background do
      schedule(@idle_poll_ms)
      {:ok, %{timer: nil}}
    else
      :ignore
    end
  end

  @impl true
  def handle_cast(:drain, state), do: {:noreply, drain(state)}

  @impl true
  def handle_info(:drain, state), do: {:noreply, drain(state)}

  defp drain(state) do
    case RedditFetchQueue.claim_next() do
      :empty ->
        schedule(@idle_poll_ms)
        state

      {:ok, job} ->
        case perform(job) do
          :offline -> schedule(@offline_poll_ms)
          _ -> schedule(1)
        end

        state
    end
  end

  @doc """
  Runs one claimed job end-to-end: dispatch → normalize → persist.

  Public so spex can drive a job without booting the timer loop. Returns
  `:ok`, `:failed`, or `:offline` (job released, try again later).
  """
  @spec perform(RedditFetchJob.t()) :: :ok | :failed | :offline
  def perform(%RedditFetchJob{} = job) do
    job = ensure_user(job)

    case transport() do
      :direct ->
        handle_result(job, Reddit.fetch(job.request))

      _agent ->
        if Dispatcher.agent_online?(job.user.id) do
          handle_result(job, Dispatcher.dispatch_reddit(job.user, job.request))
        else
          Logger.info("[Reddit.Drain] job #{job.id}: no online agent, releasing to pending")
          RedditFetchQueue.release(job)
          :offline
        end
    end
  end

  defp ensure_user(%RedditFetchJob{user: %{}} = job), do: job
  defp ensure_user(job), do: MarketMySpec.Repo.preload(job, :user)

  defp handle_result(job, result) do
    case result do
      {:ok, %{"status" => 200, "body" => body}} ->
        handle_body(job, body)

      {:ok, %{"status" => status}} ->
        finish_failed(job, {:http_status, status})

      # The agent went away mid-flight — that's not the job's fault, so put
      # it back rather than spending it.
      {:error, reason} when reason in [:agent_offline, :agent_disconnected] ->
        Logger.info("[Reddit.Drain] job #{job.id}: agent went away (#{reason}), releasing")
        RedditFetchQueue.release(job)
        :offline

      {:error, reason} ->
        finish_failed(job, reason)
    end
  end

  defp handle_body(%RedditFetchJob{kind: :search} = job, body) do
    %{candidates: candidates, next_cursor: next_cursor} = Reddit.normalize_search(body)

    # Land the threads now so the Threads surface reflects the fetch even
    # if nobody runs the search again.
    persist_threads(job, candidates)

    RedditFetchQueue.complete(job, candidates, next_cursor)
    Logger.info("[Reddit.Drain] job #{job.id}: #{length(candidates)} candidates")
    :ok
  end

  defp handle_body(%RedditFetchJob{kind: :thread} = job, body) do
    normalized = Reddit.normalize_thread(job.source_thread_id, body)

    case Map.get(normalized, :normalization_error) do
      nil ->
        upsert_thread(job, normalized)
        RedditFetchQueue.complete(job, [], nil)
        :ok

      error ->
        # Story 706: keep the prior comment_tree rather than clobbering it
        # with a bad parse, but still record the raw payload.
        upsert_thread(job, Map.drop(normalized, [:comment_tree]))
        finish_failed(job, {:normalization_error, error})
    end
  end

  defp persist_threads(job, candidates) do
    scope = scope_for(job)

    Enum.each(candidates, fn candidate ->
      ThreadsRepository.upsert_from_search(scope, :reddit, candidate)
    end)
  end

  defp upsert_thread(job, normalized) do
    scope = scope_for(job)

    ThreadsRepository.upsert_from_fetch(scope, :reddit, job.source_thread_id, normalized)
  rescue
    error ->
      Logger.warning("[Reddit.Drain] job #{job.id}: thread upsert failed: #{inspect(error)}")
      :error
  end

  defp scope_for(job) do
    %Scope{user: job.user, active_account_id: job.account_id}
  end

  defp finish_failed(job, reason) do
    Logger.warning("[Reddit.Drain] job #{job.id} failed: #{inspect(reason)}")
    RedditFetchQueue.fail(job, reason)
    :failed
  end

  defp schedule(ms), do: Process.send_after(self(), :drain, ms)

  defp config, do: Application.get_env(:market_my_spec, :reddit_fetch, [])

  defp drain_mode, do: Keyword.get(config(), :drain, :background)

  defp transport, do: Keyword.get(config(), :transport, :agent)
end
