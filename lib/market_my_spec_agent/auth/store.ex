defmodule MarketMySpecAgent.Auth.Store do
  @moduledoc """
  In-memory cache of the paired credentials, loaded from
  `MarketMySpecAgent.Auth` on startup and refreshed when
  `Pairing.run/1` writes a new token.

  Other processes (the channel client, the dispatcher) read from
  here so they don't hit the filesystem on every operation.
  """

  use GenServer

  alias MarketMySpecAgent.Auth

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Returns `{:ok, creds}` if paired, `{:error, :unpaired}` otherwise."
  def get, do: GenServer.call(__MODULE__, :get)

  @doc """
  Persists new credentials and updates the in-memory cache.
  Called from `MarketMySpecAgent.Pairing` after a successful pairing.
  """
  def put(%{} = creds), do: GenServer.call(__MODULE__, {:put, creds})

  @impl true
  def init(_) do
    case Auth.read() do
      {:ok, creds} -> {:ok, creds}
      {:error, _} -> {:ok, nil}
    end
  end

  @impl true
  def handle_call(:get, _from, nil), do: {:reply, {:error, :unpaired}, nil}
  def handle_call(:get, _from, creds), do: {:reply, {:ok, creds}, creds}

  def handle_call({:put, creds}, _from, _state) do
    :ok = Auth.write(creds)
    {:reply, :ok, creds}
  end
end
