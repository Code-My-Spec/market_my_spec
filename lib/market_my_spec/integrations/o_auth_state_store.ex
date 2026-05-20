defmodule MarketMySpec.Integrations.OAuthStateStore do
  @moduledoc """
  ETS-backed store for short-lived OAuth state parameters.
  Entries expire after #{300} seconds and are cleaned up periodically.

  ## ETS resilience

  `store/2` and `fetch/1` guard against the ETS table being temporarily
  absent during a hot-code-reload restart window in dev mode. `store/2`
  returns `:ok` silently (the OAuth request will fail gracefully due to
  missing state), and `fetch/1` returns `:error` so the OAuth callback
  falls back to an empty session_params map.
  """

  use GenServer

  @table :oauth_state_store
  @ttl_seconds 300

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def store(state, session_params) when is_binary(state) do
    :ets.insert(@table, {state, session_params, System.system_time(:second)})
    :ok
  rescue
    ArgumentError -> :ok
  end

  def fetch(state) when is_binary(state) do
    case :ets.lookup(@table, state) do
      [{^state, session_params, ts}] ->
        :ets.delete(@table, state)
        if System.system_time(:second) - ts <= @ttl_seconds,
          do: {:ok, session_params},
          else: :error

      [] ->
        :error
    end
  rescue
    ArgumentError -> :error
  end

  @impl true
  def init(_) do
    # Guard against the table already existing from a previous incarnation
    # (e.g. during hot-code-reload in dev mode).
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, read_concurrency: true])

      _info ->
        :ets.delete(@table)
        :ets.new(@table, [:named_table, :public, read_concurrency: true])
    end

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cutoff = System.system_time(:second) - @ttl_seconds
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  rescue
    ArgumentError ->
      # Table disappeared during cleanup — GenServer will be restarted by supervisor
      {:stop, :normal, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, 60_000)
end
