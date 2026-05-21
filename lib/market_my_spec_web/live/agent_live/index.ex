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

    online = Presence.online_agent_ids(user_id)

    {:ok,
     assign(socket,
       agents: load_agents(user_id, online),
       online: online,
       user_id: user_id,
       topic: topic
     )}
  end

  @impl true
  def handle_event("revoke", %{"id" => agent_id}, socket) do
    {:ok, _} = AgentsRepository.revoke_agent(socket.assigns.user_id, agent_id)

    {:noreply,
     assign(socket,
       agents: load_agents(socket.assigns.user_id, socket.assigns.online)
     )}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    online = Presence.online_agent_ids(socket.assigns.user_id)

    {:noreply,
     assign(socket,
       online: online,
       agents: load_agents(socket.assigns.user_id, online)
     )}
  end

  defp online?(online_set, agent_id), do: MapSet.member?(online_set, agent_id)

  defp load_agents(user_id, online_set) do
    user_id
    |> Agents.list_agents()
    |> Enum.sort_by(&sort_key(&1, online_set))
  end

  # Active+Online → Active+Offline → Revoked. Within a bucket, the
  # most-recently-paired agent surfaces first.
  defp sort_key(agent, online_set) do
    {bucket(agent, online_set), -DateTime.to_unix(agent.inserted_at)}
  end

  defp bucket(%{status: :revoked}, _online), do: 2
  defp bucket(agent, online_set), do: if(online?(online_set, agent.id), do: 0, else: 1)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl py-12">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-semibold">Agents</h1>
          <.link navigate={~p"/mcp-setup"} class="text-sm link link-hover">
            How to install
          </.link>
        </div>

        <%= if @agents == [] do %>
          <div class="mt-6 rounded-lg border border-base-300 p-6 text-base-content/70">
            <p>No paired agents yet.</p>
            <p class="mt-2 text-sm">
              Install the MMS Agent (<code>brew install Code-My-Spec/mms-agent/mms-agent</code>)
              then run <code>mms-agent pair</code> from your terminal.
            </p>
          </div>
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
    </Layouts.app>
    """
  end
end
