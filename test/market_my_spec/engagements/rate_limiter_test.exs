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
end
