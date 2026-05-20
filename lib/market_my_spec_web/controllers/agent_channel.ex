defmodule MarketMySpecWeb.AgentChannel do
  @moduledoc """
  Per-user channel handling binary↔server traffic. Topic is
  `agents:<user_id>`. Join validates a bearer token against
  AgentsRepository, registers the binary in Presence, and bumps the
  agent's `last_seen_at` / `version`.

  Inbound:
    * `http_response` — forwarded to whichever process is awaiting
      the matching `request_id` on Dispatcher.

  Outbound (from Endpoint.broadcast):
    * `http_request` — every binary on the topic receives this;
      only the binary whose `agent_id` matches processes it.
  """

  use Phoenix.Channel

  alias MarketMySpec.Agents
  alias MarketMySpec.Agents.AgentsRepository
  alias MarketMySpec.Agents.Presence

  intercept ["http_request"]

  @impl true
  def join("agents:" <> user_id_str, params, socket) do
    with {:ok, user_id} <- parse_user_id(user_id_str),
         {:ok, token} <- fetch_string(params, "token"),
         {:ok, agent_id} <- fetch_string(params, "agent_id"),
         {:ok, agent} <- AgentsRepository.get_active_by_token_hash(Agents.hash_token(token)),
         true <- agent.id == agent_id,
         true <- agent.user_id == user_id do
      version = Map.get(params, "version") || agent.version
      send(self(), {:after_join, version})

      {:ok,
       socket
       |> assign(:agent_id, agent.id)
       |> assign(:user_id, user_id)
       |> assign(:version, version)}
    else
      _ -> {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:after_join, version}, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.agent_id, %{
        agent_id: socket.assigns.agent_id,
        version: version,
        online_at: System.system_time(:second)
      })

    AgentsRepository.touch_last_seen(socket.assigns.user_id, socket.assigns.agent_id)

    if version do
      AgentsRepository.update_version(socket.assigns.user_id, socket.assigns.agent_id, version)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_in("http_response", %{"request_id" => req_id} = payload, socket) do
    MarketMySpecWeb.Endpoint.broadcast(
      "agent_request:#{req_id}",
      "response",
      payload
    )

    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket), do: {:noreply, socket}

  @impl true
  def handle_out("http_request", payload, socket) do
    # Forward dispatcher envelopes to the binary on the wire. Each binary
    # filters by `agent_id`; non-targets drop the message.
    push(socket, "http_request", payload)
    {:noreply, socket}
  end

  defp parse_user_id(str) do
    case Integer.parse(str) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  defp fetch_string(params, key) do
    case Map.get(params, key) do
      v when is_binary(v) and v != "" -> {:ok, v}
      _ -> :error
    end
  end
end
