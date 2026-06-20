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
        reddit: %{capacity: 6, refill_ms: 1_500}
      }
  """

  use GenServer

  require Logger

  # Reddit's anonymous RSS endpoint 429s at even ~3 concurrent requests from a
  # single datacenter IP (measured live, 2026-06-12). The failure mode is
  # *concurrency*, not sustained rate — so `capacity` (the instantaneous burst
  # ceiling) stays at 2, safely under that threshold, and we tune throughput
  # via `refill_ms` instead.
  #
  # `refill_ms` was 1_500 (one token/1.5s). At a 10s acquire timeout that let
  # only ~2 + 10000/1500 ≈ 8-9 requests clear per burst, so a single saved
  # search of 10-13 venues self-throttled a third-to-half of its venues
  # locally (reproduced 2026-06-20 with a network-free burst sim; see git
  # history). Dropping to 700ms (one token/0.7s) clears a 13-venue search at
  # 100% and an 18-venue burst at ~90%, all while peak concurrency stays at 2
  # — same simultaneity as before, just a faster queue drain. The new
  # rate-limit logging (adapter `acquire_token/1` + `drain/2`) is what we'll
  # read to decide whether heavy concurrent fan-outs warrant a further bump to
  # capacity 3. Tune via app env.
  @default_buckets %{
    reddit: %{capacity: 2, refill_ms: 700}
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
           timer: nil
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

          bucket.tokens >= 1 ->
            GenServer.reply(from, :ok)
            drain(%{bucket | tokens: bucket.tokens - 1, waiters: rest}, source)

          true ->
            bucket
        end
    end
  end

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
        wait = max(1, min(deadline - now_ms(), ms_to_token))

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
