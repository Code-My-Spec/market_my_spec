defmodule MarketMySpecWeb.AgentSocket do
  @moduledoc """
  Socket entry point for paired MMS Agent binaries. Connect is
  permissive (no auth at the socket level); the channel join
  validates the bearer token against the agent's `token_hash`.
  """

  use Phoenix.Socket

  channel "agents:*", MarketMySpecWeb.AgentChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
