defmodule MarketMySpec.Agents.Presence do
  @moduledoc """
  Tracks online agents on per-user topics `agents:<user_id>`. Metadata
  stored: `agent_id`, `version`, `online_at` (unix seconds). The
  AgentLive.Index page subscribes via Phoenix.PubSub to drive status
  pills without a refresh.

  ## ETS resilience

  `online_agent_ids/1` and `most_recently_connected/1` return safe empty
  values when the underlying `Phoenix.Tracker` ETS table is temporarily
  unavailable (e.g. during a hot-code-reload restart window in dev mode).
  """

  use Phoenix.Presence,
    otp_app: :market_my_spec,
    pubsub_server: MarketMySpec.PubSub

  @doc "Lists online agent ids for the given user_id (as a MapSet)."
  def online_agent_ids(user_id) do
    "agents:#{user_id}"
    |> list()
    |> Map.keys()
    |> MapSet.new()
  rescue
    ArgumentError -> MapSet.new()
  end

  @doc "Returns the most-recently-connected online agent id for the user, or nil."
  def most_recently_connected(user_id) do
    "agents:#{user_id}"
    |> list()
    |> Enum.flat_map(fn {agent_id, %{metas: metas}} ->
      Enum.map(metas, fn m -> {agent_id, Map.get(m, :online_at, 0)} end)
    end)
    |> case do
      [] -> nil
      list -> list |> Enum.max_by(&elem(&1, 1)) |> elem(0)
    end
  rescue
    ArgumentError -> nil
  end
end
