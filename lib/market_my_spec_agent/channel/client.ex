defmodule MarketMySpecAgent.Channel.Client do
  @moduledoc """
  Long-lived Slipstream connection to the MMS server. Joins
  `agents:<user_id>` once paired credentials are on disk, replays
  `http_request` envelopes through Req against the binary-side
  host allowlist, and pushes the `http_response` back.

  Modeled on `CodeMySpecCli.PresenceClient` in code_my_spec —
  same connect/retry/auto-rejoin pattern.

  While unpaired, retries on a slow timer (no token = no channel).
  On disconnect, retries on a fast timer.
  """

  use Slipstream
  require Logger

  alias MarketMySpec.Agents.HostAllowlist
  alias MarketMySpecAgent.Auth.Store

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
  def handle_message(topic, "http_request", payload, socket) do
    if payload["agent_id"] == socket.assigns.agent_id do
      Task.start(fn -> handle_http_request(topic, payload, socket) end)
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
  # HTTP execution
  # ---------------------------------------------------------------------------

  defp handle_http_request(topic, payload, socket) do
    response = execute_request(payload)
    push(socket, topic, "http_response", response)
  end

  defp execute_request(%{"url" => url} = req) do
    request_id = req["request_id"]
    agent_id = req["agent_id"]

    if HostAllowlist.allowed?(url) do
      do_req(url, req, request_id, agent_id)
    else
      %{
        "request_id" => request_id,
        "agent_id" => agent_id,
        "status" => 403,
        "headers" => %{},
        "body" => "host not allowed by binary-side allowlist"
      }
    end
  end

  defp do_req(url, req, request_id, agent_id) do
    method = req["method"] |> to_string() |> String.downcase() |> String.to_atom()
    headers = req["headers"] || []
    body = req["body"] || ""

    case Req.request(method: method, url: url, headers: headers, body: body) do
      {:ok, resp} ->
        %{
          "request_id" => request_id,
          "agent_id" => agent_id,
          "status" => resp.status,
          "headers" => normalize_headers(resp.headers),
          "body" => stringify_body(resp.body)
        }

      {:error, reason} ->
        %{
          "request_id" => request_id,
          "agent_id" => agent_id,
          "status" => 0,
          "headers" => %{},
          "body" => "agent transport error: #{inspect(reason)}"
        }
    end
  end

  defp normalize_headers(headers) when is_map(headers), do: headers

  defp normalize_headers(headers) when is_list(headers) do
    Enum.reduce(headers, %{}, fn
      {k, v}, acc when is_binary(k) -> Map.update(acc, k, [v], &[v | &1])
      _, acc -> acc
    end)
  end

  defp stringify_body(body) when is_binary(body), do: body
  defp stringify_body(body), do: Jason.encode!(body)

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
