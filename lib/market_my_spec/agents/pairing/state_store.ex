defmodule MarketMySpec.Agents.Pairing.StateStore do
  @moduledoc """
  ETS-backed store for pairing state lifecycles.

  Entries: `{state, status, inserted_at_ms}` where `status` is
  `:fresh` (issued on first sight) or `:consumed` (post-approve/deny).
  TTL is enforced at lookup time: an entry older than the TTL is
  treated as `:stale` regardless of status.

  Lazy creation: when the LiveView mounts with a never-seen state,
  `touch/2` inserts it as `:fresh`. That makes the store stateful
  per-LiveView mount; the binary is the source of randomness.

  ## ETS resilience

  The public API functions guard against the ETS table being temporarily
  absent (e.g. during a hot-code-reload restart window in dev mode).
  `touch/2` returns `:stale` and `consume/2` returns `{:error, :stale}`
  when the GenServer has not yet recreated its table, so callers get a
  safe "try again" signal rather than an unhandled ArgumentError.
  """

  use GenServer

  @table :market_my_spec_pairing_states

  # --- Public API ---------------------------------------------------------

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Records the state if unseen and returns its current status.
  Returns `:fresh`, `:consumed`, or `:stale`.

  Returns `:stale` if the ETS table is temporarily unavailable (e.g.
  during a hot-code-reload restart window).
  """
  def touch(state, ttl_ms) when is_binary(state) do
    now = now_ms()

    case safe_lookup(state) do
      {:error, :table_missing} ->
        :stale

      :error ->
        :ets.insert(@table, {state, :fresh, now})
        :fresh

      {:ok, {status, inserted_at}} ->
        if now - inserted_at > ttl_ms do
          :stale
        else
          status
        end
    end
  rescue
    ArgumentError -> :stale
  end

  @doc """
  Marks a state consumed. Returns `:ok`, `{:error, :consumed}`, or
  `{:error, :stale}`.

  Returns `{:error, :stale}` if the ETS table is temporarily unavailable.
  """
  def consume(state, ttl_ms) when is_binary(state) do
    now = now_ms()

    case safe_lookup(state) do
      {:error, :table_missing} ->
        {:error, :stale}

      :error ->
        :ets.insert(@table, {state, :consumed, now})
        :ok

      {:ok, {:fresh, inserted_at}} ->
        if now - inserted_at > ttl_ms do
          {:error, :stale}
        else
          :ets.insert(@table, {state, :consumed, inserted_at})
          :ok
        end

      {:ok, {:consumed, _}} ->
        {:error, :consumed}
    end
  rescue
    ArgumentError -> {:error, :stale}
  end

  # --- GenServer ----------------------------------------------------------

  @impl true
  def init(_) do
    # Guard against the table already existing from a previous incarnation
    # (e.g. if the process is restarted during a hot-code-reload and the
    # old table hasn't been cleaned up yet — rare but possible in dev mode).
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

      _info ->
        # Table exists — take ownership: delete and recreate so this
        # process is the new owner.
        :ets.delete(@table)
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    end

    {:ok, %{}}
  end

  # Returns :error when the state is absent, {:ok, {status, inserted_at}}
  # when found, or {:error, :table_missing} when the ETS table doesn't exist.
  defp safe_lookup(state) do
    case :ets.lookup(@table, state) do
      [{^state, status, inserted_at}] -> {:ok, {status, inserted_at}}
      [] -> :error
    end
  rescue
    ArgumentError -> {:error, :table_missing}
  end

  defp now_ms, do: System.system_time(:millisecond)
end
