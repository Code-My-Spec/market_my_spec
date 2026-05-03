defmodule MarketMySpec.Integrations.OAuthStateStore do
  use GenServer

  @table :oauth_state_store
  @ttl_seconds 300

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def store(state, session_params) when is_binary(state) do
    :ets.insert(@table, {state, session_params, System.system_time(:second)})
    :ok
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
  end

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cutoff = System.system_time(:second) - @ttl_seconds
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, 60_000)
end
