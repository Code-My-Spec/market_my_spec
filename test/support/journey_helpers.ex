defmodule MarketMySpec.JourneyHelpers do
  @moduledoc """
  Helpers for `MarketMySpecWeb.JourneyCase` — Wallaby-cookie restore,
  OAuth bearer minting against a deployed env's `/oauth/*` surface,
  Anubis MCP client startup, and `mms-agent` binary lifecycle.

  See `.code_my_spec/qa/sessions/SETUP.md` for the one-time session
  capture procedure that produces the JSON files this module reads.
  """

  @sessions_dir Path.expand("../../.code_my_spec/qa/sessions", __DIR__)

  @env_urls %{
    dev: "http://localhost:4007",
    uat: "https://uat.marketmyspec.com",
    prod: "https://marketmyspec.com"
  }

  @doc "Base HTTP URL for the named env."
  def base_url(env), do: Map.fetch!(@env_urls, env)

  @doc """
  Restores cookies from `.code_my_spec/qa/sessions/<env>.json` into an
  already-started Wallaby session. Use this from `JourneyCase` where
  `Wallaby.Feature.__using__/1` has already allocated a session.

  Returns `{:ok, session}` or `{:error, reason}`. Reasons include
  `:no_session_file`, `{:bad_json, _}`.
  """
  def restore_session_into(%Wallaby.Session{} = session, env) when env in [:dev, :uat, :prod] do
    path = Path.join(@sessions_dir, "#{env}.json")

    with {:ok, body} <- File.read(path),
         {:ok, %{"cookies" => cookies}} <- Jason.decode(body) do
      restore_cookies_into(session, env, cookies)
    else
      {:error, :enoent} -> {:error, :no_session_file}
      {:error, %Jason.DecodeError{} = err} -> {:error, {:bad_json, err}}
    end
  end

  defp restore_cookies_into(session, env, cookies) do
    # Webdriver requires a navigation to the target domain before
    # set_cookie will accept domain-scoped cookies. Visit a cheap
    # path first (the login page is fine — it 200s either way).
    Wallaby.Browser.visit(session, "#{base_url(env)}/users/log-in")

    Enum.each(cookies, fn cookie ->
      # Preserve the full cookie attributes. Wallaby's set_cookie
      # filters keys via `Map.take(~w[path domain secure httpOnly expiry]a)`
      # — note the camelCase `httpOnly`. snake_case `http_only` gets
      # silently dropped on the floor, leaving Phoenix's session cookie
      # in a state Chrome may reject on HTTPS.
      attrs = [
        domain: cookie["domain"],
        path: cookie["path"] || "/",
        secure: cookie["secure"] == true,
        httpOnly: cookie["httpOnly"] == true
      ]

      attrs =
        case cookie["expires"] do
          n when is_number(n) and n > 0 -> Keyword.put(attrs, :expiry, trunc(n))
          _ -> attrs
        end

      Wallaby.Browser.set_cookie(
        session,
        cookie["name"],
        cookie["value"],
        attrs
      )
    end)

    {:ok, session}
  end

  @doc """
  Mints an MCP bearer token against the named env. Uses the existing
  Wallaby session (which must be signed-in via `restore_session/1`)
  to drive the `/oauth/authorize` LiveView and approve the consent
  screen, then exchanges the resulting code for a bearer at
  `/oauth/token`. Dynamic-registers an OAuth client per call so each
  test is isolated.

  Returns `{:ok, bearer_string}` or `{:error, reason}`.
  """
  def mint_bearer(session, env, opts \\ []) do
    base = base_url(env)
    # Redirect to a real same-domain page that returns 200 for a
    # signed-in user and does NOT bounce. /users/register has a
    # redirect_if_user_is_authenticated guard that 302s a signed-in
    # user to "/", stripping the ?code= before we can read it.
    # /mcp-setup is behind require_authenticated_user → 200 for us,
    # ignores the extra query params, preserves the URL.
    redirect_uri = Keyword.get(opts, :redirect_uri, "#{base}/mcp-setup")
    scope = Keyword.get(opts, :scope, "read write")

    with {:ok, %{"client_id" => cid, "client_secret" => csec}} <-
           register_oauth_client(base, redirect_uri),
         {:ok, code} <- drive_authorize(session, base, cid, redirect_uri, scope),
         {:ok, body} <- exchange_code_for_token(base, cid, csec, code, redirect_uri) do
      {:ok, body["access_token"]}
    end
  end

  defp register_oauth_client(base, redirect_uri) do
    case Req.post("#{base}/oauth/register",
           json: %{
             "client_name" => "journey-test",
             "redirect_uris" => [redirect_uri]
           }) do
      {:ok, %Req.Response{status: 201, body: body}} -> {:ok, body}
      other -> {:error, {:register, other}}
    end
  end

  defp drive_authorize(session, base, client_id, redirect_uri, scope) do
    state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    # McpAuthorizationLive.mount/3 handles a `decision=approve` param
    # server-side (no phx-click needed — the consent button is just the
    # interactive equivalent). Passing decision=approve makes mount call
    # handle_authorize → redirect to redirect_uri?code=&state=. This
    # avoids the LiveView-socket-connect timing race that plagues
    # clicking a phx-click button via Wallaby on a remote server.
    url =
      "#{base}/oauth/authorize?" <>
        URI.encode_query(%{
          "response_type" => "code",
          "client_id" => client_id,
          "redirect_uri" => redirect_uri,
          "scope" => scope,
          "state" => state,
          "decision" => "approve"
        })

    Wallaby.Browser.visit(session, url)

    # The redirect lands on redirect_uri (a real same-domain 200 page) with
    # ?code= in the URL. Poll current_url until it shows up.
    await_code(session, 10_000)
  end

  defp await_code(session, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_code(session, deadline)
  end

  defp do_await_code(session, deadline) do
    current = Wallaby.Browser.current_url(session)

    code =
      case URI.parse(current) do
        %URI{query: q} when is_binary(q) -> URI.decode_query(q)["code"]
        _ -> nil
      end

    cond do
      is_binary(code) -> {:ok, code}
      System.monotonic_time(:millisecond) >= deadline -> {:error, {:no_code_in_redirect, current}}
      true ->
        Process.sleep(500)
        do_await_code(session, deadline)
    end
  end

  defp exchange_code_for_token(base, client_id, client_secret, code, redirect_uri) do
    case Req.post("#{base}/oauth/token",
           form: [
             grant_type: "authorization_code",
             code: code,
             redirect_uri: redirect_uri,
             client_id: client_id,
             client_secret: client_secret
           ]) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        Jason.decode(body)

      other ->
        {:error, {:token_exchange, other}}
    end
  end

  @doc """
  Starts an `Anubis.Client` pointed at the env's `/mcp` endpoint,
  with the bearer token in the `Authorization` header. Returns the
  client pid (usable as the first arg to `Anubis.Client.call_tool/3`
  and friends).
  """
  def start_mcp_client(env, bearer, opts \\ []) do
    name = Keyword.get(opts, :name, Module.concat(__MODULE__, env))

    # start_link returns {:ok, supervisor_pid}, but call_tool/list_tools
    # route by the registered client NAME (the supervisor pid would hit
    # :supervisor.handle_call and crash). Return the name for callers.
    case Anubis.Client.start_link(
           name: name,
           transport:
             {:streamable_http,
              base_url: base_url(env),
              mcp_path: "/mcp",
              headers: %{"authorization" => "Bearer #{bearer}"}},
           client_info: %{"name" => "journey-test", "version" => "1.0"},
           capabilities: %{},
           protocol_version: "2025-06-18"
         ) do
      {:ok, _sup} ->
        # The MCP initialize handshake runs async after start_link.
        # Block until it completes, otherwise the first call_tool races
        # ahead of capability negotiation and the server replies
        # "Server capabilities not set".
        case Anubis.Client.await_ready(name, timeout: 15_000) do
          :ok -> {:ok, name}
          other -> other
        end

      other ->
        other
    end
  end

  @doc """
  Calls an MCP tool through the started client and returns the tool's
  decoded JSON payload — not the raw MCP envelope.

  Anubis returns `{:ok, %Anubis.MCP.Response{result: %{"content" =>
  [%{"type" => "text", "text" => "<json>"}]}}}`; the actual tool output
  is the JSON string in the first text content block. This unwraps +
  Jason.decodes it so callers can assert on the tool's own keys
  (`"candidates"`, `"notices"`, etc).
  """
  def call_tool(client, tool_name, args) do
    case Anubis.Client.call_tool(client, tool_name, args) do
      {:ok, %Anubis.MCP.Response{result: result}} ->
        {:ok, unwrap_tool_payload(result)}

      other ->
        other
    end
  end

  defp unwrap_tool_payload(%{"content" => content}) when is_list(content) do
    text =
      content
      |> Enum.find_value(fn
        %{"text" => t} when is_binary(t) -> t
        _ -> nil
      end)

    case text && Jason.decode(text) do
      {:ok, decoded} -> decoded
      _ -> %{"raw" => text, "result" => %{"content" => content}}
    end
  end

  defp unwrap_tool_payload(other), do: other

  @doc """
  Calls a tool repeatedly until `predicate.(payload)` returns true or
  `timeout_ms` elapses. Returns `{:ok, payload}` on success or
  `{:error, {:predicate_never_true, last_payload}}`. Used to absorb
  eventual-consistency lag — e.g. Phoenix.Presence taking a beat to
  clear a disconnected agent before the dispatcher sees it gone.
  """
  def call_tool_until(client, tool_name, args, predicate, timeout_ms \\ 20_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_call_until(client, tool_name, args, predicate, deadline, nil)
  end

  defp do_call_until(client, tool_name, args, predicate, deadline, last) do
    payload =
      case call_tool(client, tool_name, args) do
        {:ok, p} -> p
        _ -> last
      end

    cond do
      is_map(payload) and predicate.(payload) ->
        {:ok, payload}

      System.monotonic_time(:millisecond) >= deadline ->
        {:error, {:predicate_never_true, payload}}

      true ->
        Process.sleep(2_000)
        do_call_until(client, tool_name, args, predicate, deadline, payload)
    end
  end

  @doc """
  Re-visits `path` and checks for `text`, polling until found or
  `timeout_ms` elapses. Returns true/false. Wallaby's own assert_has
  retries, but only within a single page render — this re-navigates,
  which is what we need when waiting on a Phoenix.Presence diff to
  propagate to the LiveView after an out-of-band channel join/leave.
  """
  def wait_for_page_text(session, path, text, timeout_ms \\ 20_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_for_text(session, path, text, deadline)
  end

  defp do_wait_for_text(session, path, text, deadline) do
    Wallaby.Browser.visit(session, path)

    found? =
      try do
        body = Wallaby.Browser.text(session)
        String.contains?(body, text)
      rescue
        _ -> false
      end

    cond do
      found? -> true
      System.monotonic_time(:millisecond) >= deadline -> false
      true ->
        Process.sleep(1_500)
        do_wait_for_text(session, path, text, deadline)
    end
  end

  @doc """
  Kills any running `mms-agent` process. Idempotent. Used in test
  teardown so a hung pair-flow binary doesn't leak across tests.
  """
  def kill_agent_binary do
    _ = System.cmd("pkill", ["-f", "market_my_spec_agent"], stderr_to_stdout: true)
    :ok
  end

  @doc """
  Starts `mms-agent --env <env> server` in the background, redirecting
  its (very noisy) stdout/stderr to a log file so it doesn't pollute
  the test's own output. Returns `{:ok, log_path}`. Honors
  `MMS_SERVER_URL` override. Teardown happens via `kill_agent_binary/0`.
  """
  def start_agent_binary(env, opts \\ []) do
    server_url = Keyword.get(opts, :server_url, base_url(env))
    log_path = Keyword.get(opts, :log_path, Path.join(System.tmp_dir!(), "mms-agent-#{env}.log"))

    # Spawn detached via sh so the burrito debug spew + logger output
    # land in a file, not interleaved into ExUnit's stdout. We don't
    # hold the Port — kill_agent_binary/0 reaps it by name on teardown.
    _ =
      spawn(fn ->
        System.cmd(
          "sh",
          ["-c", "MMS_SERVER_URL=#{server_url} mms-agent --env #{env} server > #{log_path} 2>&1"],
          stderr_to_stdout: true
        )
      end)

    {:ok, log_path}
  end

  @doc """
  Polls until the agent's log shows it joined the channel, or `timeout_ms`
  elapses. Returns `:ok` or `{:error, :timeout}`. More reliable than a
  fixed sleep — burrito extraction + BEAM boot + WSS connect + channel
  join is 5-12s and varies with cold/warm cache.
  """
  def await_agent_joined(log_path, timeout_ms \\ 25_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_joined(log_path, deadline)
  end

  defp do_await_joined(log_path, deadline) do
    joined? =
      case File.read(log_path) do
        {:ok, body} -> String.contains?(body, "joined agents:")
        _ -> false
      end

    cond do
      joined? -> :ok
      System.monotonic_time(:millisecond) >= deadline -> {:error, :timeout}
      true ->
        Process.sleep(1_000)
        do_await_joined(log_path, deadline)
    end
  end
end
