defmodule MarketMySpec.Engagements.RateLimiterTest do
  @moduledoc """
  Token-bucket timing is exercised here directly against a dedicated limiter
  instance (the app-wide one is unthrottled in test config). These assertions
  use generous wall-clock margins so they stay stable under a loaded CI box.
  """
  use ExUnit.Case, async: true

  alias MarketMySpec.Engagements.RateLimiter

  defp start_limiter(buckets) do
    name = :"rate_limiter_#{System.unique_integer([:positive])}"
    pid = start_supervised!({RateLimiter, name: name, buckets: buckets})
    {pid, name}
  end

  test "grants up to capacity tokens instantly, then paces the rest by refill" do
    {_pid, name} = start_limiter(%{reddit: %{capacity: 3, refill_ms: 100}})

    # First `capacity` acquisitions are immediate (the initial burst).
    assert :ok = RateLimiter.acquire(:reddit, 1_000, name)
    assert :ok = RateLimiter.acquire(:reddit, 1_000, name)
    assert :ok = RateLimiter.acquire(:reddit, 1_000, name)

    # The 4th has to wait for a refill (~100ms), but still succeeds.
    {micros, :ok} = :timer.tc(fn -> RateLimiter.acquire(:reddit, 1_000, name) end)
    assert micros >= 80_000, "expected the 4th token to wait for a refill, waited #{micros}us"
  end

  test "returns {:error, :rate_limit_timeout} when no token frees up in time" do
    # capacity 1, very slow refill: the second acquire can't be funded before
    # its short timeout elapses.
    {_pid, name} = start_limiter(%{reddit: %{capacity: 1, refill_ms: 10_000}})

    assert :ok = RateLimiter.acquire(:reddit, 1_000, name)
    assert {:error, :rate_limit_timeout} = RateLimiter.acquire(:reddit, 150, name)
  end

  test "unconfigured sources are unthrottled" do
    {_pid, name} = start_limiter(%{reddit: %{capacity: 1, refill_ms: 10_000}})

    # elixirforum has no bucket → always immediate, regardless of reddit's state.
    assert :ok = RateLimiter.acquire(:reddit, 1_000, name)
    assert :ok = RateLimiter.acquire(:elixirforum, 1, name)
    assert :ok = RateLimiter.acquire(:elixirforum, 1, name)
  end

  test "concurrent waiters are each served as tokens refill" do
    {_pid, name} = start_limiter(%{reddit: %{capacity: 1, refill_ms: 100}})

    # Drain the initial token, then fire 3 waiters concurrently. Each should
    # eventually get :ok as the bucket refills one token per 100ms.
    assert :ok = RateLimiter.acquire(:reddit, 2_000, name)

    results =
      1..3
      |> Enum.map(fn _ -> Task.async(fn -> RateLimiter.acquire(:reddit, 5_000, name) end) end)
      |> Task.await_many(6_000)

    assert results == [:ok, :ok, :ok]
  end

  describe "report/3 (respecting the source's window)" do
    test "remaining<=0 blocks the bucket until the reported reset elapses" do
      # Fast refill so the only thing that could hold a waiter is the reported
      # window, not the token bucket.
      {_pid, name} = start_limiter(%{reddit: %{capacity: 1, refill_ms: 50}})

      # Source says: budget exhausted, window resets in ~0.4s.
      RateLimiter.report(:reddit, 0.0, 0.4, name)

      # A short-timeout acquire can't get through during the block.
      assert {:error, :rate_limit_timeout} = RateLimiter.acquire(:reddit, 150, name)
    end

    test "acquire blocks for the reported window before being granted" do
      {_pid, name} = start_limiter(%{reddit: %{capacity: 1, refill_ms: 50}})

      # Measured immediately after report/4 with nothing in between, on
      # purpose. An earlier version timed this acquire *after* a short
      # acquire that was expected to eat ~150ms of the 400ms window — but
      # under load that short acquire's timeout can consume the whole
      # window, leaving nothing left to wait for and failing with
      # "waited 12us". The assertion has to depend only on the window, not
      # on how long an unrelated call happened to take.
      #
      # `report/4` is a cast and `acquire/3` a call from this same process,
      # so ordering is guaranteed — the block is in place before we ask.
      window_ms = 400
      RateLimiter.report(:reddit, 0.0, window_ms / 1_000, name)

      {micros, :ok} = :timer.tc(fn -> RateLimiter.acquire(:reddit, 5_000, name) end)

      # Floor well under the window (timer granularity can fire a touch
      # early) but far above the "returned immediately" failure it guards.
      assert micros >= 300_000,
             "expected acquire to wait out the ~#{window_ms}ms window, waited #{micros}us"
    end

    test "remaining>0 does not block" do
      {_pid, name} = start_limiter(%{reddit: %{capacity: 1, refill_ms: 50}})

      RateLimiter.report(:reddit, 5.0, 60.0, name)

      assert :ok = RateLimiter.acquire(:reddit, 200, name)
    end

    test "report for an unconfigured source is a no-op" do
      {_pid, name} = start_limiter(%{reddit: %{capacity: 1, refill_ms: 50}})

      assert :ok = RateLimiter.report(:elixirforum, 0.0, 60.0, name)
      assert :ok = RateLimiter.acquire(:elixirforum, 1, name)
    end
  end
end
