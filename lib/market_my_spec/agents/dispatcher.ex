defmodule MarketMySpec.Agents.Dispatcher do
  @moduledoc """
  Server→agent HTTP request orchestrator. Broadcasts an `http_request`
  envelope on `agents:<user_id>` to the user's most-recently-connected
  online agent, awaits a matching `http_response`, and returns
  `{:ok, %{status, headers, body}}` or an error term.

  Errors:
    * `{:error, :host_not_allowed}` — URL host not in allowlist
    * `{:error, :agent_offline}` — no online agent for the user
    * `{:error, :timeout}` — no response within the deadline
    * `{:error, :agent_disconnected}` — agent left mid-flight

  Talks to `Phoenix.PubSub` directly (not `MarketMySpecWeb.Endpoint`)
  to keep the agents context independent of the web layer.
  """

  alias MarketMySpec.Agents.HostAllowlist
  alias MarketMySpec.Agents.Presence

  @default_timeout 30_000
  @pubsub MarketMySpec.PubSub

  def dispatch_http(user, %{url: url} = req, opts \\ []) do
    if HostAllowlist.allowed?(url) do
      case Presence.most_recently_connected(user.id) do
        nil ->
          {:error, :agent_offline}

        agent_id ->
          do_dispatch(user, agent_id, req, opts)
      end
    else
      {:error, :host_not_allowed}
    end
  end

  defp do_dispatch(user, agent_id, req, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    request_id = generate_request_id()
    response_topic = "agent_request:#{request_id}"
    user_topic = "agents:#{user.id}"

    Phoenix.PubSub.subscribe(@pubsub, response_topic)
    Phoenix.PubSub.subscribe(@pubsub, user_topic)

    Phoenix.PubSub.broadcast(@pubsub, user_topic, %Phoenix.Socket.Broadcast{
      topic: user_topic,
      event: "http_request",
      payload: %{
        "request_id" => request_id,
        "agent_id" => agent_id,
        "method" => Map.get(req, :method, :get),
        "url" => req.url,
        "headers" => Map.get(req, :headers, []),
        "body" => Map.get(req, :body, "")
      }
    })

    result = await_response(agent_id, response_topic, timeout)

    Phoenix.PubSub.unsubscribe(@pubsub, response_topic)
    Phoenix.PubSub.unsubscribe(@pubsub, user_topic)

    result
  end

  defp await_response(agent_id, response_topic, timeout) do
    receive do
      %Phoenix.Socket.Broadcast{event: "response", topic: ^response_topic, payload: payload} ->
        {:ok,
         %{
           status: payload["status"] || payload[:status],
           headers: payload["headers"] || payload[:headers] || %{},
           body: payload["body"] || payload[:body] || ""
         }}

      %Phoenix.Socket.Broadcast{event: "presence_diff", payload: %{leaves: leaves}} ->
        if Map.has_key?(leaves, agent_id) do
          {:error, :agent_disconnected}
        else
          await_response(agent_id, response_topic, timeout)
        end
    after
      timeout -> {:error, :timeout}
    end
  end

  defp generate_request_id, do: :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
end
