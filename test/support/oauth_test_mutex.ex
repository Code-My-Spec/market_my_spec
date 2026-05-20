defmodule MarketMySpecSpex.OAuthTestMutex do
  @moduledoc """
  Process-based serialization lock for tests that mutate the Assent HTTP
  adapter in Application env.

  GenServer.call/3 serializes callers via the process mailbox. This lock
  uses a two-phase protocol: `acquire/0` blocks until the lock is free and
  returns a release token; `release/1` frees the lock so the next waiter
  can proceed. The critical section runs in the CALLER'S process (not the
  GenServer's), so Phoenix.ConnTest message-passing during request dispatch
  works correctly.

  Usage:

      token = OAuthTestMutex.acquire()
      try do
        # ... critical section
      after
        OAuthTestMutex.release(token)
      end

  Or use `exclusive/1` which wraps the try/after:

      OAuthTestMutex.exclusive(fn -> ... end)

  The server is started lazily on first use — no explicit start required
  in test_helper.exs.

  ## Deadlock prevention

  When the lock holder's process dies before calling `release/1` (e.g. a
  test times out or is killed by ExUnit), the GenServer detects the DOWN
  signal via a monitor and automatically releases the lock, waking the
  next waiter. This prevents the permanent deadlock that would otherwise
  occur when a high-concurrency run kills a test mid-critical-section.
  """

  use GenServer

  @name __MODULE__
  @acquire_timeout 30_000

  @doc """
  Ensures the mutex GenServer is running. Safe to call concurrently.
  """
  def ensure_started do
    case GenServer.start(__MODULE__, nil, name: @name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  @doc """
  Acquires the lock. Blocks until the lock is free (up to 30 s).
  Returns an opaque release token. Always call `release/1` in an `after`
  block to avoid deadlocks.
  """
  def acquire do
    ensure_started()
    GenServer.call(@name, :acquire, @acquire_timeout)
  end

  @doc """
  Releases the lock. Must be called with the token returned by `acquire/0`.
  """
  def release(token) do
    GenServer.cast(@name, {:release, token})
  end

  @doc """
  Runs `fun` while holding the mutex. Returns the result of `fun`.
  The function executes in the caller's process.
  """
  def exclusive(fun) when is_function(fun, 0) do
    token = acquire()

    try do
      fun.()
    after
      release(token)
    end
  end

  # ---- GenServer implementation ----

  defmodule State do
    @moduledoc false
    defstruct locked: false, token: nil, holder_monitor: nil, queue: :queue.new()
  end

  @impl true
  def init(nil), do: {:ok, %State{}}

  @impl true
  def handle_call(:acquire, {caller_pid, _tag}, %State{locked: false} = state) do
    token = make_ref()
    monitor_ref = Process.monitor(caller_pid)

    {:reply, token,
     %State{state | locked: true, token: token, holder_monitor: monitor_ref, queue: :queue.new()}}
  end

  def handle_call(:acquire, from, %State{locked: true} = state) do
    new_queue = :queue.in(from, state.queue)
    {:noreply, %State{state | queue: new_queue}}
  end

  @impl true
  def handle_cast({:release, _token}, %State{locked: false} = state) do
    # Already unlocked — ignore stale release
    {:noreply, state}
  end

  def handle_cast({:release, token}, %State{locked: true, token: token} = state) do
    # Demonitor the previous holder since it released cleanly
    if state.holder_monitor, do: Process.demonitor(state.holder_monitor, [:flush])
    do_release(state)
  end

  def handle_cast({:release, _wrong_token}, state) do
    # Token mismatch — ignore
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %State{holder_monitor: ref} = state) do
    # Lock holder died (test killed / timed out). Auto-release so waiters aren't stuck.
    do_release(state)
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Stale monitor from a previous holder — ignore
    {:noreply, state}
  end

  # Pops the next waiter from the queue and grants them the lock,
  # or marks the mutex as unlocked if the queue is empty.
  defp do_release(%State{} = state) do
    case :queue.out(state.queue) do
      {:empty, _} ->
        {:noreply, %State{state | locked: false, token: nil, holder_monitor: nil}}

      {{:value, {next_pid, _tag} = next_from}, remaining_queue} ->
        new_token = make_ref()
        new_monitor = Process.monitor(next_pid)
        GenServer.reply(next_from, new_token)
        {:noreply, %State{state | token: new_token, holder_monitor: new_monitor, queue: remaining_queue}}
    end
  end
end
