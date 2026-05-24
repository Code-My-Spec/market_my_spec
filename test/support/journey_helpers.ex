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
    redirect_uri = Keyword.get(opts, :redirect_uri, "https://localhost.invalid/cb")
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

    url =
      "#{base}/oauth/authorize?" <>
        URI.encode_query(%{
          "response_type" => "code",
          "client_id" => client_id,
          "redirect_uri" => redirect_uri,
          "scope" => scope,
          "state" => state
        })

    session
    |> Wallaby.Browser.visit(url)
    |> click_approve_when_present()

    current = Wallaby.Browser.current_url(session)

    case URI.parse(current) do
      %URI{query: nil} ->
        {:error, {:no_code_in_redirect, current}}

      %URI{query: q} ->
        params = URI.decode_query(q)

        case params do
          %{"code" => code} -> {:ok, code}
          _ -> {:error, {:no_code_in_redirect, current}}
        end
    end
  end

  defp click_approve_when_present(session) do
    # The /oauth/authorize LiveView shows an Approve button for
    # signed-in users. If the page auto-approves (consent skipped),
    # there's nothing to click — the redirect already fired.
    try do
      Wallaby.Browser.click(session, Wallaby.Query.button("Approve"))
    rescue
      _ -> session
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
    url = "#{base_url(env)}/mcp"

    Anubis.Client.start_link(
      name: name,
      transport:
        {:streamable_http,
         url: url,
         headers: %{"authorization" => "Bearer #{bearer}"}},
      client_info: %{"name" => "journey-test", "version" => "1.0"},
      capabilities: %{},
      protocol_version: "2025-06-18"
    )
  end

  @doc """
  Calls an MCP tool through the started client. Wraps
  `Anubis.Client.call_tool/3` so tests don't need to import Anubis.
  """
  def call_tool(client, tool_name, args) do
    Anubis.Client.call_tool(client, tool_name, args)
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
  Starts `mms-agent --env <env> server` as a Port. Returns `{:ok, port}`.
  Caller should `Port.close(port)` (or just let test teardown's
  `kill_agent_binary/0` fire). Honors `MMS_SERVER_URL` override.
  """
  def start_agent_binary(env, opts \\ []) do
    server_url = Keyword.get(opts, :server_url, base_url(env))

    port =
      Port.open(
        {:spawn_executable, System.find_executable("mms-agent")},
        [
          :binary,
          :exit_status,
          args: ["--env", to_string(env), "server"],
          env: [{~c"MMS_SERVER_URL", String.to_charlist(server_url)}]
        ]
      )

    {:ok, port}
  end
end
