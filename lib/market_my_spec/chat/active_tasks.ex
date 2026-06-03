defmodule MarketMySpec.Chat.ActiveTasks do
  @moduledoc """
  Tracks in-flight streaming replies so a remounting LiveView can recover
  partial state (R4).

  Keyed by `chat_id` (the Conversation id), each entry holds
  `%{message_id, status: :streaming | :error, acc_text}`. The Runner registers
  an entry when a reply starts, appends accumulated text as chunks arrive, and
  the entry is cleared on `:stream_done` / `:stream_error`. On `mount/3` the
  LiveView reads the entry to restore the partial assistant text and the
  in-progress indicator.

  Backed by a named, public ETS table: reads are direct (no GenServer round
  trip); writes are serialized through the GenServer because appends are
  read-modify-write.
  """

  use GenServer

  @table :chat_active_tasks

  @type entry :: %{
          message_id: Ecto.UUID.t(),
          status: :streaming | :error,
          acc_text: String.t()
        }

  # --- Client ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Register a new streaming reply for `chat_id`."
  @spec track(term(), Ecto.UUID.t()) :: :ok
  def track(chat_id, message_id) do
    GenServer.call(__MODULE__, {:track, chat_id, message_id})
  end

  @doc "Append a streamed text delta to the in-flight reply for `chat_id`."
  @spec append(term(), String.t()) :: :ok
  def append(chat_id, delta) do
    GenServer.call(__MODULE__, {:append, chat_id, delta})
  end

  @doc "Mark the in-flight reply for `chat_id` as errored."
  @spec mark_error(term()) :: :ok
  def mark_error(chat_id) do
    GenServer.call(__MODULE__, {:mark_error, chat_id})
  end

  @doc "Clear any tracked state for `chat_id`."
  @spec clear(term()) :: :ok
  def clear(chat_id) do
    GenServer.call(__MODULE__, {:clear, chat_id})
  end

  @doc "Read the tracked entry for `chat_id`, or `nil`. Direct ETS read."
  @spec get(term()) :: entry() | nil
  def get(chat_id) do
    case :ets.whereis(@table) do
      :undefined ->
        nil

      _ ->
        case :ets.lookup(@table, chat_id) do
          [{^chat_id, entry}] -> entry
          [] -> nil
        end
    end
  end

  # --- Server ---

  @impl GenServer
  def init(:ok) do
    table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_call({:track, chat_id, message_id}, _from, state) do
    :ets.insert(@table, {chat_id, %{message_id: message_id, status: :streaming, acc_text: ""}})
    {:reply, :ok, state}
  end

  def handle_call({:append, chat_id, delta}, _from, state) do
    case :ets.lookup(@table, chat_id) do
      [{^chat_id, %{acc_text: acc} = entry}] ->
        :ets.insert(@table, {chat_id, %{entry | acc_text: acc <> delta}})

      [] ->
        :ok
    end

    {:reply, :ok, state}
  end

  def handle_call({:mark_error, chat_id}, _from, state) do
    case :ets.lookup(@table, chat_id) do
      [{^chat_id, entry}] -> :ets.insert(@table, {chat_id, %{entry | status: :error}})
      [] -> :ok
    end

    {:reply, :ok, state}
  end

  def handle_call({:clear, chat_id}, _from, state) do
    :ets.delete(@table, chat_id)
    {:reply, :ok, state}
  end
end
