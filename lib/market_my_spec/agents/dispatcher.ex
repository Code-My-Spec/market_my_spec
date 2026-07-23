defmodule MarketMySpec.Agents.Dispatcher do
  @moduledoc """
  Server→agent Reddit fetch orchestrator. Broadcasts a `reddit_fetch`
  envelope on `agents:<user_id>` to the user's most-recently-connected
  online agent, awaits a matching `reddit_result`, and returns
  `{:ok, %{"status" => …, "body" => …}}` or an error term.

  The envelope carries a request map built by
  `Engagements.Source.Reddit.build_search_request/3` or
  `build_thread_request/2` — a path and ordered params, never a URL and
  never a host. The binary bakes in its own base URL, so this channel
  cannot be used to make the agent fetch something that isn't a Reddit
  RSS feed.

  Errors:
    * `{:error, :agent_offline}` — no online agent for the user
    * `{:error, :timeout}` — no response within the deadline
    * `{:error, :agent_disconnected}` — agent left mid-flight
    * `{:error, {:agent_error, reason}}` — the binary failed the fetch

  Talks to `Phoenix.PubSub` directly (not `MarketMySpecWeb.Endpoint`)
  to keep the agents context independent of the web layer.
  """

  alias MarketMySpec.Agents.AgentsRepository
  alias MarketMySpec.Agents.Presence

  # Must exceed the binary's own per-fetch ceiling (Reddit.Worker's
  # @call_timeout, 120s) so a fetch that is merely slow — queued behind
  # another, or waiting out Reddit's 60s window — comes back as a real
  # result instead of being cut off here and reported as a timeout.
  @default_timeout 150_000
  @pubsub MarketMySpec.PubSub

  @doc """
  Dispatches one Reddit fetch through `user`'s online agent.

  `request` is the map from `Reddit.build_search_request/3` or
  `Reddit.build_thread_request/2`.
  """
  @spec dispatch_reddit(map(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def dispatch_reddit(user, request, opts \\ []) do
    case pick_active_online_agent(user.id) do
      nil -> {:error, :agent_offline}
      agent_id -> do_dispatch(user, agent_id, request, opts)
    end
  end

  @doc """
  Returns true when `user` has an agent that is both online in Presence
  and still `:active` in the database.

  The queue drain checks this before pulling work so jobs stay pending
  (rather than burning attempts) while the binary is offline.
  """
  @spec agent_online?(map() | integer()) :: boolean()
  def agent_online?(%{id: user_id}), do: agent_online?(user_id)
  def agent_online?(user_id), do: not is_nil(pick_active_online_agent(user_id))

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

  defp do_dispatch(user, agent_id, request, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    request_id = generate_request_id()
    response_topic = "agent_request:#{request_id}"
    user_topic = "agents:#{user.id}"

    Phoenix.PubSub.subscribe(@pubsub, response_topic)
    Phoenix.PubSub.subscribe(@pubsub, user_topic)

    payload =
      request
      |> Map.take(["kind", "path", "params", "source_thread_id", "label"])
      |> Map.merge(%{"request_id" => request_id, "agent_id" => agent_id})

    Phoenix.PubSub.broadcast(@pubsub, user_topic, %Phoenix.Socket.Broadcast{
      topic: user_topic,
      event: "reddit_fetch",
      payload: payload
    })

    result = await_response(agent_id, response_topic, timeout)

    Phoenix.PubSub.unsubscribe(@pubsub, response_topic)
    Phoenix.PubSub.unsubscribe(@pubsub, user_topic)

    result
  end

  defp await_response(agent_id, response_topic, timeout) do
    receive do
      %Phoenix.Socket.Broadcast{event: "response", topic: ^response_topic, payload: payload} ->
        decode_result(payload)

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

  # The binary reports transport failures as status 0 plus an `error`
  # string. Surface those as errors rather than letting a 0/"" response
  # normalize into an empty (but successful-looking) feed.
  defp decode_result(payload) do
    status = payload["status"] || payload[:status] || 0
    body = payload["body"] || payload[:body] || ""
    error = payload["error"] || payload[:error]

    cond do
      is_binary(error) and error != "" -> {:error, {:agent_error, error}}
      status == 0 -> {:error, {:agent_error, "no status"}}
      true -> {:ok, %{"status" => status, "body" => body}}
    end
  end

  defp generate_request_id, do: :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
end
