defmodule MarketMySpec.Engagements.RateLimiter do
  @moduledoc """
  Per-source token-bucket rate limiter for Engagement Source adapters.

  Reddit serves its anonymous RSS feeds from a single shared IP pool with a
  burst tolerance well under what a fan-out of saved searches produces
  (running 5 searches × 6 venues = 30 simultaneous requests trips HTTP 429).
  The 429s degrade gracefully into the caller's `failures` list, but every
  subsequent search to the same venues then returns zero candidates until the
  throttle clears — a false "no fresh threads" for ~2-3 minutes.

  This GenServer sits in front of the network call: `acquire/3` blocks the
  calling Task until a token is available for the source, smoothing bursts so
  the 429 is never triggered in the first place. A request that cannot get a
  token within its timeout returns `{:error, :rate_limit_timeout}` — a clean,
  immediate failure (surfaced as a "Rate limited" notice) rather than a slow
  429 that also poisons the next search.

  ## Buckets

  Each source has an independent bucket (Reddit and ElixirForum have separate
  rate-limit pools, so they never share tokens). A bucket is
  `%{capacity, refill_ms}` — `capacity` tokens available for an instantaneous
  burst, refilling one token every `refill_ms`. Sources with no configured
  bucket are unthrottled: `acquire/3` returns `:ok` immediately.

  Defaults are overridable via application env (set to `%{}` in test to make
  every source unthrottled):

      config :market_my_spec, :engagement_rate_limiter, %{
        reddit: %{capacity: 1, refill_ms: 5_000}
      }

  ## Respecting the source's own limit (`report/3`)

  Measured live (2026-06-21), Reddit's anonymous RSS endpoint enforces a
  fixed ~60s window allowing ~1 request per window from a single IP. It
  signals state via `x-ratelimit-remaining` and `x-ratelimit-reset` (seconds
  until the window rolls over) — there is no `Retry-After`. So blind
  token-bucket pacing can't keep up: it either under-uses the budget or trips
  429s that poison the next window.

  After each response, the HTTP layer calls `report/3` with the observed
  `remaining`/`reset`. When `remaining <= 0` the bucket is blocked until
  `now + reset`, so the next `acquire/3` waits out Reddit's actual window
  rather than guessing. The token bucket (capacity 1) still serializes
  requests one-at-a-time; the reported window is the real gate.
  """

  use GenServer

  require Logger

  # Reddit's anonymous RSS endpoint enforces a fixed ~60s window of ~1 request
  # from a single IP (measured live 2026-06-21 via x-ratelimit-* headers — see
  # report/3 and the moduledoc). Earlier params (cap=2/refill=700ms) assumed
  # the limiter itself was the bottleneck; live testing proved otherwise — the
  # wall is Reddit-side, so we serialize (capacity 1) and let report/3 block
  # the bucket for the window Reddit actually reports. `refill_ms` is just a
  # floor that paces requests before/without any header signal (cassette tests,
  # the first request of a window); the reported reset is the real gate.
  @default_buckets %{
    reddit: %{capacity: 1, refill_ms: 5_000}
  }

  @default_timeout 5_000

  # ── Public API ─────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Blocks until a token is available for `source`, then returns `:ok`.

  Returns `{:error, :rate_limit_timeout}` if no token frees up within
  `timeout` milliseconds. Sources without a configured bucket return `:ok`
  immediately. Fails open (`:ok`) if the limiter process is unavailable — a
  request through is better than blocking all searching on a downed limiter.
  """
  @spec acquire(atom(), timeout(), GenServer.server()) :: :ok | {:error, :rate_limit_timeout}
  def acquire(source, timeout \\ @default_timeout, server \\ __MODULE__) do
    GenServer.call(server, {:acquire, source, timeout}, timeout + 2_000)
  catch
    :exit, reason ->
      Logger.warning("RateLimiter.acquire/#{source} failed open: #{inspect(reason)}")
      :ok
  end

  @doc """
  Reports the source's own rate-limit state, observed from a response.

  `remaining` and `reset_seconds` come straight from the source's headers
  (Reddit's `x-ratelimit-remaining` / `x-ratelimit-reset`). When `remaining`
  is at or below zero the bucket is blocked until `now + reset_seconds`, so the
  next `acquire/3` waits out the source's actual window instead of the local
  refill guess. Fire-and-forget: a no-op for unconfigured sources, and never
  blocks the caller (cast).
  """
  @spec report(atom(), number(), number(), GenServer.server()) :: :ok
  def report(source, remaining, reset_seconds, server \\ __MODULE__) do
    GenServer.cast(server, {:report, source, remaining, reset_seconds})
  catch
    :exit, _reason -> :ok
  end

  # ── GenServer callbacks ────────────────────────────────────────────────

  @impl true
  def init(opts) do
    cfg =
      Keyword.get(opts, :buckets) ||
        Application.get_env(:market_my_spec, :engagement_rate_limiter, @default_buckets)

    buckets =
      Map.new(cfg, fn {source, %{capacity: cap, refill_ms: refill_ms}} ->
        {source,
         %{
           tokens: cap * 1.0,
           capacity: cap,
           refill_ms: refill_ms,
           last: now_ms(),
           waiters: :queue.new(),
           timer: nil,
           # A monotonic-time instant before which grants are held. Defaults to
           # "now" (not 0 — monotonic time can be negative, which would read as
           # permanently blocked). report/3 pushes it into the future.
           blocked_until: now_ms()
         }}
      end)

    {:ok, %{buckets: buckets}}
  end

  @impl true
  def handle_call({:acquire, source, timeout}, from, state) do
    case Map.fetch(state.buckets, source) do
      :error ->
        # Unthrottled source — grant immediately.
        {:reply, :ok, state}

      {:ok, bucket} ->
        deadline = now_ms() + timeout

        bucket =
          bucket
          |> enqueue(from, deadline)
          |> drain(source)
          |> schedule(source)

        {:noreply, put_bucket(state, source, bucket)}
    end
  end

  @impl true
  def handle_cast({:report, source, remaining, reset_seconds}, state) do
    case Map.fetch(state.buckets, source) do
      :error ->
        {:noreply, state}

      {:ok, bucket} ->
        bucket =
          bucket
          |> apply_report(remaining, reset_seconds)
          |> drain(source)
          |> schedule(source)

        {:noreply, put_bucket(state, source, bucket)}
    end
  end

  @impl true
  def handle_info({:drain, source}, state) do
    case Map.fetch(state.buckets, source) do
      :error ->
        {:noreply, state}

      {:ok, bucket} ->
        bucket =
          %{bucket | timer: nil}
          |> drain(source)
          |> schedule(source)

        {:noreply, put_bucket(state, source, bucket)}
    end
  end

  # ── Bucket mechanics ───────────────────────────────────────────────────

  defp enqueue(bucket, from, deadline) do
    %{bucket | waiters: :queue.in({from, deadline}, bucket.waiters)}
  end

  # Reply to as many head-of-line waiters as we have tokens for. Expired
  # waiters are dropped (replied with the timeout error) without consuming a
  # token. Stops at the first waiter that is neither expired nor fundable.
  defp drain(bucket, source) do
    bucket = refill(bucket)

    case :queue.out(bucket.waiters) do
      {:empty, _} ->
        bucket

      {{:value, {from, deadline}}, rest} ->
        cond do
          now_ms() >= deadline ->
            Logger.warning(
              "RateLimiter[#{source}]: dropped a waiter (acquire timeout); " <>
                "tokens=#{Float.round(bucket.tokens, 2)} remaining_queue=#{:queue.len(rest)}"
            )

            GenServer.reply(from, {:error, :rate_limit_timeout})
            drain(%{bucket | waiters: rest}, source)

          now_ms() < bucket.blocked_until ->
            # The source reported its window is exhausted; hold every waiter
            # until it resets (schedule/2 wakes us at blocked_until).
            bucket

          bucket.tokens >= 1 ->
            GenServer.reply(from, :ok)
            drain(%{bucket | tokens: bucket.tokens - 1, waiters: rest}, source)

          true ->
            bucket
        end
    end
  end

  # Fold a reported rate-limit state into the bucket. When the source says it
  # has no budget left, block until its window resets and zero out tokens so a
  # stale local token can't sneak a request through during the block.
  defp apply_report(bucket, remaining, reset_seconds) when remaining <= 0 do
    blocked_until = now_ms() + round(reset_seconds * 1000)
    %{bucket | tokens: 0.0, blocked_until: max(bucket.blocked_until, blocked_until)}
  end

  defp apply_report(bucket, _remaining, _reset_seconds), do: bucket

  defp refill(bucket) do
    now = now_ms()
    added = (now - bucket.last) / bucket.refill_ms
    tokens = min(bucket.capacity * 1.0, bucket.tokens + added)
    %{bucket | tokens: tokens, last: now}
  end

  # Wake the bucket up when the next token (or the head waiter's deadline,
  # whichever comes first) is due, so a queued caller never waits longer than
  # necessary. No-op when the queue is empty.
  defp schedule(bucket, source) do
    case :queue.peek(bucket.waiters) do
      :empty ->
        cancel_timer(bucket)

      {:value, {_from, deadline}} ->
        ms_to_token = ceil(max(0.0, 1 - bucket.tokens) * bucket.refill_ms)
        ms_to_unblock = max(0, bucket.blocked_until - now_ms())
        # Wake when BOTH a token is available AND the reported window has
        # reset — but never past the head waiter's deadline.
        wait = max(1, min(deadline - now_ms(), max(ms_to_token, ms_to_unblock)))

        bucket = cancel_timer(bucket)
        ref = Process.send_after(self(), {:drain, source}, wait)
        %{bucket | timer: ref}
    end
  end

  defp cancel_timer(%{timer: nil} = bucket), do: bucket

  defp cancel_timer(%{timer: ref} = bucket) do
    Process.cancel_timer(ref)
    %{bucket | timer: nil}
  end

  defp put_bucket(state, source, bucket) do
    %{state | buckets: Map.put(state.buckets, source, bucket)}
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end
