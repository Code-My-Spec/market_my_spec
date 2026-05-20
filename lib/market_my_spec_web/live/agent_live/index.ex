defmodule MarketMySpecWeb.AgentLive.Index do
  @moduledoc """
  Lists the user's paired agents. Subscribes to the per-user
  presence topic so status pills flip without a refresh.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Agents
  alias MarketMySpec.Agents.AgentsRepository
  alias MarketMySpec.Agents.Presence

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    topic = "agents:#{user_id}"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(MarketMySpec.PubSub, topic)
    end

    {:ok,
     assign(socket,
       agents: Agents.list_agents(user_id),
       online: Presence.online_agent_ids(user_id),
       user_id: user_id,
       topic: topic
     )}
  end

  @impl true
  def handle_event("revoke", %{"id" => agent_id}, socket) do
    {:ok, _} = AgentsRepository.revoke_agent(socket.assigns.user_id, agent_id)
    {:noreply, assign(socket, agents: Agents.list_agents(socket.assigns.user_id))}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply,
     assign(socket,
       online: Presence.online_agent_ids(socket.assigns.user_id),
       agents: Agents.list_agents(socket.assigns.user_id)
     )}
  end

  defp online?(online_set, agent_id), do: MapSet.member?(online_set, agent_id)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl py-12">
      <h1 class="text-2xl font-semibold">Agents</h1>

      <%= if @agents == [] do %>
        <p class="mt-6 text-base-content/70">No paired agents yet.</p>
      <% else %>
        <ul class="mt-6 space-y-3">
          <li :for={a <- @agents} class="rounded-lg border p-4">
            <div class="flex items-center justify-between">
              <div>
                <p class="font-medium">{a.name}</p>
                <p class="text-sm text-base-content/70">
                  <%= cond do %>
                    <% a.status == :revoked -> %>
                      <span>Revoked</span>
                    <% online?(@online, a.id) -> %>
                      <span data-test={"status-online-#{a.id}"}>Online</span>
                    <% true -> %>
                      <span data-test={"status-offline-#{a.id}"}>Offline</span>
                  <% end %>
                  <%= if a.version do %>
                    · v{a.version}
                  <% end %>
                  <%= if a.last_seen_at do %>
                    · last seen {Calendar.strftime(a.last_seen_at, "%Y-%m-%d %H:%M:%S")}
                  <% else %>
                    · never connected
                  <% end %>
                </p>
              </div>
              <%= if a.status == :active do %>
                <button
                  data-test={"revoke-agent-#{a.id}"}
                  phx-click="revoke"
                  phx-value-id={a.id}
                  class="btn btn-sm"
                >
                  Revoke
                </button>
              <% end %>
            </div>
          </li>
        </ul>
      <% end %>
    </div>
    """
  end
end
