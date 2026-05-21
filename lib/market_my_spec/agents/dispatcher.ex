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

  alias MarketMySpec.Agents.AgentsRepository
  alias MarketMySpec.Agents.HostAllowlist
  alias MarketMySpec.Agents.Presence

  @default_timeout 30_000
  @pubsub MarketMySpec.PubSub

  def dispatch_http(user, %{url: url} = req, opts \\ []) do
    if HostAllowlist.allowed?(url) do
      case pick_active_online_agent(user.id) do
        nil ->
          {:error, :agent_offline}

        agent_id ->
          do_dispatch(user, agent_id, req, opts)
      end
    else
      {:error, :host_not_allowed}
    end
  end

  # Returns the most-recently-connected agent id that is still :active
  # in the DB. A revoked agent whose channel hadn't been force-closed
  # could still appear in Presence with a high `online_at` — without
  # this filter the Dispatcher would broadcast to a doomed agent and
  # time out.
  defp pick_active_online_agent(user_id) do
    active_ids = AgentsRepository.active_agent_id_set(user_id)

    user_id
    |> Presence.online_agent_ids_by_recency()
    |> Enum.find(&MapSet.member?(active_ids, &1))
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
        "method" => to_string(Map.get(req, :method, :get)),
        "url" => req.url,
        "headers" => normalize_headers(Map.get(req, :headers, [])),
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

  # Phoenix channels serialize the broadcast payload as JSON before pushing
  # to the binary. Tuples don't implement `Jason.Encoder`, so a raw
  # `[{"user-agent", "…"}]` list crashes the channel mid-`handle_out/3`
  # (presence_diff fires, Dispatcher sees `:agent_disconnected` — but the
  # real cause is right here). Coerce header entries to two-element lists
  # so they JSON-encode as `["user-agent", "…"]`; the binary's `Req` call
  # accepts the same shape.
  defp normalize_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {k, v} -> [to_string(k), to_string(v)] end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Enum.map(headers, fn
      {k, v} -> [to_string(k), to_string(v)]
      [k, v] -> [to_string(k), to_string(v)]
      other -> other
    end)
  end

  defp normalize_headers(_), do: []
end
