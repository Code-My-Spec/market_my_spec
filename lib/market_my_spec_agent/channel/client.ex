defmodule MarketMySpecAgent.Channel.Client do
  @moduledoc """
  Long-lived Slipstream connection to the MMS server. Joins
  `agents:<user_id>` once paired credentials are on disk, runs
  `reddit_fetch` envelopes through `MarketMySpecAgent.Reddit.Worker`
  (which serializes them and enforces the 1/min limit), and pushes the
  `reddit_result` back.

  The envelope carries a path + params built by
  `Engagements.Source.Reddit`, never a URL — the base URL is baked into
  the client on this side, so the server cannot steer the binary at an
  arbitrary host.

  Modeled on `CodeMySpecCli.PresenceClient` in code_my_spec —
  same connect/retry/auto-rejoin pattern.

  While unpaired, retries on a slow timer (no token = no channel).
  On disconnect, retries on a fast timer.
  """

  use Slipstream
  require Logger

  alias MarketMySpecAgent.Auth.Store
  alias MarketMySpecAgent.Reddit.Worker

  @retry_unauth_ms 10_000
  @retry_disconnect_ms 5_000

  def start_link(_opts) do
    Slipstream.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Slipstream
  def init(_args) do
    Logger.info("[Agent.Channel.Client] starting")
    send(self(), :try_connect)
    {:ok, new_socket()}
  end

  @impl Slipstream
  def handle_info(:try_connect, socket) do
    Logger.info("[Agent.Channel.Client] try_connect tick")

    case Store.get() do
      {:ok, creds} ->
        ws_url = ws_url_for(creds["server_url"])
        Logger.info("[Agent.Channel.Client] attempting connect to #{ws_url}")

        case connect(socket, uri: ws_url) do
          {:ok, configured_socket} ->
            Logger.info("[Agent.Channel.Client] connect/2 returned {:ok, _} — awaiting handle_connect")

            assigns = %{
              user_id: to_string(creds["user_id"]),
              agent_id: creds["agent_id"],
              token: creds["token"],
              topic: "agents:#{creds["user_id"]}"
            }

            {:noreply, assign(configured_socket, assigns)}

          {:error, reason} ->
            Logger.warning("[Agent.Channel.Client] connect error: #{inspect(reason)}")
            Process.send_after(self(), :try_connect, @retry_disconnect_ms)
            {:noreply, socket}
        end

      {:error, :unpaired} ->
        Logger.info("[Agent.Channel.Client] not paired yet; retrying in #{@retry_unauth_ms}ms")
        Process.send_after(self(), :try_connect, @retry_unauth_ms)
        {:noreply, socket}
    end
  end

  def handle_info({:agent_response, topic, response}, socket) do
    Logger.info(
      "[Agent.Channel.Client] reddit_result status=#{inspect(response["status"])} " <>
        "request_id=#{inspect(response["request_id"])}"
    )

    push(socket, topic, "reddit_result", response)
    {:noreply, socket}
  end

  @impl Slipstream
  def handle_connect(socket) do
    %{topic: topic, agent_id: agent_id, token: token} = socket.assigns
    Logger.info("[Agent.Channel.Client] connected — joining #{topic}")

    {:ok,
     join(socket, topic, %{
       "agent_id" => agent_id,
       "token" => token,
       "version" => version()
     })}
  end

  @impl Slipstream
  def handle_join(topic, _reply, socket) do
    Logger.info("[Agent.Channel.Client] joined #{topic}")
    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(topic, "reddit_fetch", payload, socket) do
    if payload["agent_id"] == socket.assigns.agent_id do
      # Run the fetch in a Task so the channel process stays responsive to
      # heartbeats — a fetch can sit for a full minute waiting on the rate
      # limiter, which would otherwise block this GenServer's mailbox and
      # get the connection torn down as missed-heartbeat. Serialization
      # still happens: the Task calls into Reddit.Worker, which is the
      # single point that talks to Reddit.
      #
      # The Task hands the response back via a message so `push/4` runs
      # inside the channel process — calling push from a foreign process
      # has stranded responses in Slipstream's frame queue before.
      channel_pid = self()
      Logger.info("[Agent.Channel.Client] reddit_fetch → #{inspect(payload["label"])}")

      Task.start(fn ->
        response = execute_fetch(payload)
        send(channel_pid, {:agent_response, topic, response})
      end)
    end

    {:ok, socket}
  end

  def handle_message(_topic, _event, _payload, socket), do: {:ok, socket}

  @impl Slipstream
  def handle_disconnect(reason, socket) do
    Logger.warning("[Agent.Channel.Client] disconnected: #{inspect(reason)}")
    Process.send_after(self(), :try_connect, @retry_disconnect_ms)
    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Reddit fetch execution
  # ---------------------------------------------------------------------------

  # `status` is echoed straight through, including 429 — the server decides
  # what a status means. A transport failure becomes status 0 with the
  # reason in `error`, which the Dispatcher surfaces as a venue failure
  # rather than silently reading as an empty feed.
  defp execute_fetch(payload) do
    base = %{
      "request_id" => payload["request_id"],
      "agent_id" => payload["agent_id"]
    }

    case Worker.fetch(request_of(payload)) do
      {:ok, %{"status" => status, "body" => body}} ->
        Map.merge(base, %{"status" => status, "body" => body})

      {:error, reason} ->
        Map.merge(base, %{"status" => 0, "body" => "", "error" => inspect(reason)})
    end
  end

  # The envelope carries dispatch metadata alongside the request; hand the
  # worker only the request fields so a future metadata key can't be
  # mistaken for a request field.
  defp request_of(payload) do
    Map.take(payload, ["kind", "path", "params", "source_thread_id", "label"])
  end

  # ---------------------------------------------------------------------------
  # URL + version helpers
  # ---------------------------------------------------------------------------

  defp ws_url_for(http_url) do
    uri = URI.parse(http_url)
    scheme = if uri.scheme == "https", do: "wss", else: "ws"
    port = uri.port || default_port(uri.scheme)
    "#{scheme}://#{uri.host}:#{port}/agent/websocket?vsn=2.0.0"
  end

  defp default_port("https"), do: 443
  defp default_port(_), do: 80

  defp version do
    case Application.spec(:market_my_spec, :vsn) do
      nil -> "0.0.0"
      v -> to_string(v)
    end
  end
end
