defmodule MarketMySpecWeb.AgentLive.Pair do
  @moduledoc """
  Pairing approval LiveView. The binary opens
  /agents/pair?state=...&port=...&name=...; this view validates the
  params, shows the consent screen, and on Approve/Deny redirects
  back to the binary's loopback callback.
  """

  use MarketMySpecWeb, :live_view

  alias MarketMySpec.Agents.Pairing

  @impl true
  def mount(params, _session, socket) do
    state = params["state"]
    port = params["port"]
    name = params["name"] || "your binary"

    if missing_params?(state, port) do
      {:ok, assign(socket, status: :invalid_params)}
    else
      {:ok, apply_pairing_result(socket, state, port, name)}
    end
  end

  defp missing_params?(state, port) do
    is_nil(state) or state == "" or is_nil(port) or port == ""
  end

  defp apply_pairing_result(socket, state, port, name) do
    case Pairing.start_pairing(socket.assigns.current_scope, %{
           "state" => state,
           "port" => port,
           "name" => name
         }) do
      {:ok, :ready} ->
        assign(socket, status: :ready, state: state, port: port, agent_name: name)

      {:error, reason} when reason in [:consumed, :stale] ->
        assign(socket, status: :unavailable)

      {:error, _} ->
        assign(socket, status: :invalid_params)
    end
  end

  @impl true
  def handle_event("approve", _params, socket) do
    case Pairing.complete_pairing(
           socket.assigns.current_scope,
           socket.assigns.state,
           socket.assigns.agent_name
         ) do
      {:ok, %{token: token, agent: agent}} ->
        {:noreply,
         redirect(socket,
           external:
             callback_url(socket.assigns.port, %{
               "token" => token,
               "agent_id" => agent.id,
               "user_id" => to_string(agent.user_id)
             })
         )}

      {:error, _} ->
        {:noreply, assign(socket, status: :unavailable)}
    end
  end

  def handle_event("deny", _params, socket) do
    _ = Pairing.deny_pairing(socket.assigns.state)

    {:noreply,
     redirect(socket,
       external: callback_url(socket.assigns.port, %{"denied" => "true"})
     )}
  end

  defp callback_url(port, params) do
    "http://localhost:#{port}/callback?" <> URI.encode_query(params)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-lg py-12">
      <%= case @status do %>
        <% :ready -> %>
          <h1 class="text-2xl font-semibold">Pair this binary</h1>
          <p class="mt-4">Approve to let <strong>{@agent_name}</strong> connect to your account.</p>
          <div class="mt-6 flex gap-3">
            <button data-test="approve-pairing" phx-click="approve" class="btn btn-primary">
              Approve
            </button>
            <button data-test="deny-pairing" phx-click="deny" class="btn">
              Deny
            </button>
          </div>
        <% :unavailable -> %>
          <h1 class="text-2xl font-semibold">Pairing session unavailable — restart your agent</h1>
        <% :invalid_params -> %>
          <h1 class="text-2xl font-semibold">Invalid pairing link — restart your agent</h1>
      <% end %>
    </div>
    """
  end
end
