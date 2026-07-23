defmodule MarketMySpec.AgentsTestHelpers do
  @moduledoc """
  Spex bridge for the agents context. Wraps Phoenix.ChannelTest and
  PubSub interactions so spex modules don't reach into MarketMySpecWeb
  or Phoenix.PubSub directly — everything funnels through
  `MarketMySpecSpex.Fixtures` (which defdelegates here).
  """

  import Phoenix.ChannelTest
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint MarketMySpecWeb.Endpoint

  alias MarketMySpec.Agents.Presence

  @doc """
  Drives the pairing LiveView end-to-end for an authenticated `conn`
  and returns `{agent, token}` so the spec can use them immediately.

  Opts:
    * `:port` (default 51_234)
    * `:name` (default "spex-box")
  """
  def pair_via_ui(conn, user, opts \\ []) do
    port = Keyword.get(opts, :port, 51_234)
    name = Keyword.get(opts, :name, "spex-box")
    state = "ui-#{System.unique_integer([:positive])}"

    url = "/app/agents/pair?state=#{state}&port=#{port}&name=#{URI.encode(name)}"

    {:ok, view, _} = live(conn, url)

    view
    |> element("[data-test='approve-pairing']")
    |> render_click()

    {redirect_url, _flash} = assert_redirect(view)
    %URI{query: q} = URI.parse(redirect_url)
    token = URI.decode_query(q || "") |> Map.fetch!("token")

    [agent] =
      MarketMySpec.Agents.list_agents(user.id)
      |> Enum.filter(&(&1.name == name))

    {agent, token}
  end

  @doc """
  Joins the agents channel for `user_id` with `agent_id` + `token`.
  Returns the Phoenix.ChannelTest result tuple. After a successful
  join, blocks until Presence has registered the agent so subsequent
  dispatcher calls see it.
  """
  def join_agent_channel(user_id, agent_id, token, opts \\ []) do
    params = %{"agent_id" => agent_id, "token" => token}

    params =
      case Keyword.get(opts, :version) do
        nil -> params
        v -> Map.put(params, "version", v)
      end

    result =
      MarketMySpecWeb.AgentSocket
      |> socket("agent:#{agent_id}", %{})
      |> subscribe_and_join(MarketMySpecWeb.AgentChannel, "agents:#{user_id}", params)

    case result do
      {:ok, _reply, channel_socket} ->
        # Force the channel process to drain its mailbox (including
        # `:after_join`) before returning.
        :sys.get_state(channel_socket.channel_pid)
        wait_for_presence(user_id, agent_id, 500)
        result

      _ ->
        result
    end
  end

  defp wait_for_presence(user_id, agent_id, deadline_ms) do
    topic = "agents:#{user_id}"
    online = Presence.list(topic)

    cond do
      Map.has_key?(online, agent_id) ->
        :ok

      deadline_ms <= 0 ->
        :timeout

      true ->
        Process.sleep(10)
        wait_for_presence(user_id, agent_id, deadline_ms - 10)
    end
  end

  @doc "Subscribes the calling process to the per-user agents topic."
  def subscribe_to_agent_topic(user_id) do
    Phoenix.PubSub.subscribe(MarketMySpec.PubSub, "agents:#{user_id}")
  end

  @doc """
  Waits for a `reddit_fetch` envelope on the subscribed agents topic
  and returns its payload. Flunks the spec on timeout.
  """
  def expect_reddit_fetch_envelope(timeout \\ 2_000) do
    receive do
      %Phoenix.Socket.Broadcast{event: "reddit_fetch", payload: payload} -> payload
    after
      timeout -> ExUnit.Assertions.flunk("expected reddit_fetch envelope within #{timeout}ms")
    end
  end

  @doc """
  Receives any reddit_fetch broadcast within `timeout`. Returns
  `:no_broadcast` if none arrives — useful for assert-no-broadcast cases.
  """
  def receive_reddit_fetch_envelope(timeout) do
    receive do
      %Phoenix.Socket.Broadcast{event: "reddit_fetch"} -> :received
    after
      timeout -> :no_broadcast
    end
  end

  @doc """
  Broadcasts the binary's `reddit_result` on the per-request response topic,
  matching the request_id from the envelope.

  No headers: the agent returns status + raw feed body only. Interpretation
  (including of a 429) is the server's job — see `Agents.Dispatcher`.
  """
  def respond_to_envelope(envelope, status, body) do
    topic = "agent_request:#{envelope["request_id"]}"

    Phoenix.PubSub.broadcast(MarketMySpec.PubSub, topic, %Phoenix.Socket.Broadcast{
      topic: topic,
      event: "response",
      payload: %{
        "agent_id" => envelope["agent_id"],
        "request_id" => envelope["request_id"],
        "status" => status,
        "body" => body
      }
    })
  end

  @doc """
  Closes a channel socket. Sets `:trap_exit` so the EXIT signals
  from the channel/transport teardown become inert messages rather
  than killing the test process. ExUnit tears the process down at
  test end (no manual drain needed). Presence still untracks the
  agent via its process monitor — that's the behavior under test.
  """
  def kill_channel(channel_socket) do
    Process.flag(:trap_exit, true)
    pid = channel_socket.channel_pid
    ref = Process.monitor(pid)
    Phoenix.ChannelTest.close(channel_socket)

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      1_000 -> ExUnit.Assertions.flunk("channel did not close within 1s")
    end
  end

  @doc "Drives /agents revoke button click for `agent_id` from a connected `conn`."
  def revoke_via_agents_page(conn, agent_id) do
    {:ok, view, _} = live(conn, "/app/agents")

    view
    |> element("[data-test='revoke-agent-#{agent_id}']")
    |> render_click()

    :ok
  end
end
