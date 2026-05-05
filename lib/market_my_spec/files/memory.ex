defmodule MarketMySpec.Files.Memory do
  @moduledoc """
  In-memory ETS-backed implementation of `MarketMySpec.Files.Behaviour`.

  Used in tests to avoid real S3 calls. Each test process gets an isolated
  table via `start_link/0`. The module also supports a shared global table
  (`:market_my_spec_files_memory`) created at application start in the test
  environment so that concurrent tests sharing the SQL sandbox can also share
  file state within a single test run.

  The table is keyed by the full account-scoped key (e.g.
  `accounts/42/marketing/05_positioning.md`). Prefix-based listing scans all
  entries and filters by prefix.
  """

  @behaviour MarketMySpec.Files.Behaviour

  @table :market_my_spec_files_memory

  @doc """
  Ensures the ETS table exists. Call once from `Application.start/2` in the
  test environment or from test setup.
  """
  def ensure_table do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set])
    end

    :ok
  end

  @impl true
  def put(key, body, opts \\ []) when is_binary(key) and is_binary(body) and is_list(opts) do
    ensure_table()
    metadata = %{key: key, size: byte_size(body), last_modified: DateTime.utc_now()}
    :ets.insert(@table, {key, body, metadata})
    {:ok, metadata}
  end

  @impl true
  def get(key) when is_binary(key) do
    ensure_table()

    case :ets.lookup(@table, key) do
      [{^key, body, _metadata}] -> {:ok, body}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def list(prefix) when is_binary(prefix) do
    ensure_table()

    entries =
      :ets.tab2list(@table)
      |> Enum.filter(fn {k, _body, _meta} -> String.starts_with?(k, prefix) end)
      |> Enum.map(fn {_k, _body, meta} -> meta end)
      |> Enum.sort_by(& &1.key)

    {:ok, entries}
  end

  @impl true
  def delete(key) when is_binary(key) do
    ensure_table()

    case :ets.lookup(@table, key) do
      [{^key, _, _}] ->
        :ets.delete(@table, key)
        :ok

      [] ->
        {:error, :not_found}
    end
  end
end
