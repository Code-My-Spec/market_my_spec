defmodule MarketMySpecAgent.Pairing do
  @moduledoc """
  First-run pairing flow on the binary side.

  Sequence:

  1. Generate a single-use random state token.
  2. Bind an ephemeral loopback TCP port and start a one-shot
     Bandit + Plug listener at `localhost:<port>/callback`.
  3. Open the browser at
     `<server>/agents/pair?state=<state>&port=<port>&name=<hostname>`.
  4. Block until the listener receives the redirect, then either
     persist credentials and return `:ok`, or return `{:error, :denied}`.
  """

  alias MarketMySpecAgent.Auth.Store

  @timeout_ms 5 * 60 * 1_000

  @doc """
  Runs the pairing flow. Blocks until the user approves, denies,
  or the listener times out.

  Opts:
    * `:server_url`   — defaults to `MMS_SERVER_URL` env var, then
      `Application.get_env(:market_my_spec, :server_url)`. The env-var
      override lets a developer pair through the Cloudflare tunnel
      (`MMS_SERVER_URL=https://dev.marketmyspec.com just agent pair`)
      so browser cookies match and the LiveView's redirect to
      `http://localhost:<port>/callback` isn't blocked as mixed content.
    * `:agent_name`   — defaults to the system hostname
    * `:open_browser` — fun/1 that takes the URL and opens it. Default
      shells out to `open` / `xdg-open` / `start`. Override in tests.
  """
  def run(opts \\ []) do
    server_url = Keyword.get(opts, :server_url) || default_server_url()
    agent_name = Keyword.get(opts, :agent_name) || default_hostname()

    IO.puts("[Pairing] server_url = #{server_url}")
    open_browser = Keyword.get(opts, :open_browser, &open_url/1)

    state = generate_state()
    port = pick_free_port()
    ref = make_ref()
    caller = self()
    {:ok, listener_pid} = start_listener(port, caller, ref)

    pair_url =
      "#{server_url}/agents/pair?" <>
        URI.encode_query(%{"state" => state, "port" => to_string(port), "name" => agent_name})

    IO.puts("Opening browser at: #{pair_url}")
    IO.puts("If the browser doesn't open, visit the URL above manually.")
    open_browser.(pair_url)

    result =
      receive do
        {:pair_callback, ^ref, params} ->
          handle_callback(params, server_url)
      after
        @timeout_ms ->
          {:error, :timeout}
      end

    _ = GenServer.stop(listener_pid, :normal, 1_000)
    result
  end

  defp handle_callback(%{"token" => token, "agent_id" => agent_id, "user_id" => user_id}, server_url) do
    creds = %{
      "agent_id" => agent_id,
      "user_id" => user_id,
      "token" => token,
      "server_url" => server_url,
      "paired_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    :ok = Store.put(creds)
    :ok
  end

  defp handle_callback(%{"denied" => "true"}, _server_url), do: {:error, :denied}
  defp handle_callback(_, _), do: {:error, :invalid_callback}

  defp generate_state, do: :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

  defp start_listener(port, caller, ref) do
    Bandit.start_link(
      plug: {MarketMySpecAgent.Pairing.CallbackPlug, %{caller: caller, ref: ref}},
      scheme: :http,
      ip: {127, 0, 0, 1},
      port: port
    )
  end

  defp pick_free_port do
    {:ok, sock} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, reuseaddr: true)
    {:ok, port} = :inet.port(sock)
    :gen_tcp.close(sock)
    port
  end

  defp default_server_url do
    System.get_env("MMS_SERVER_URL") ||
      Application.get_env(:market_my_spec, :server_url, "http://localhost:4007")
  end

  defp default_hostname do
    case :inet.gethostname() do
      {:ok, name} -> to_string(name)
      _ -> "mms-agent"
    end
  end

  defp open_url(url) do
    cmd =
      case :os.type() do
        {:unix, :darwin} -> "open"
        {:unix, _} -> "xdg-open"
        {:win32, _} -> "start"
      end

    _ = System.cmd(cmd, [url], stderr_to_stdout: true)
    :ok
  end
end
