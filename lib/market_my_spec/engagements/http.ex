defmodule MarketMySpec.Engagements.HTTP do
  @moduledoc """
  Req client factories for Engagements source adapters.

  Reddit and Discourse adapters call into this module to get a configured
  `%Req.Request{}` rather than rolling their own. Centralizing here lets:

  - User-Agent / base URL conventions stay consistent across adapters.
  - Tests inject a ReqCassette plug via `:reddit_req_options` /
    `:elixirforum_req_options` application env. The plug is merged via
    `Req.merge/2` and runs through Req's standard Plug adapter pipeline,
    intercepting requests before they hit the network. See
    `test/support/reddit_spex_helpers.ex` (Reddit) and
    `test/support/elixir_forum_spex_helpers.ex` (ElixirForum) for the
    helper pattern.
  - Future retry / rate-limit / auth changes happen in one place.

  Per knowledge/req-and-cassette-stack.md.
  """

  alias MarketMySpec.Engagements.Source.RedditCookieJar

  @reddit_user_agent "market_my_spec/0.1 by /u/johns10davenport"
  @elixirforum_user_agent "market_my_spec/0.1 (engagement-finder; contact: johns10@gmail.com)"

  @doc """
  Returns an anonymous-read Reddit client targeting `www.reddit.com`.

  v1 of story 705 uses anonymous read — no bearer, no OAuth. The
  descriptive User-Agent is the only requirement Reddit enforces for
  public listing/search endpoints. OAuth (with TokenStore) is deferred
  to story 707 when the agent needs the `submit` scope.

  Merge `:reddit_req_options` from app env so tests can inject the
  ReqCassette plug returned by `with_cassette`.
  """
  @spec reddit_client() :: Req.Request.t()
  def reddit_client do
    Req.new(
      base_url: "https://www.reddit.com",
      headers: [{"user-agent", @reddit_user_agent}],
      retry: &reddit_retry/2,
      max_retries: 2,
      retry_delay: &reddit_retry_delay/1,
      connect_options: [transport_opts: tls_transport_opts()]
    )
    |> Req.Request.append_request_steps(reddit_send_cookie: &send_stored_cookie/1)
    |> Req.Request.append_response_steps(reddit_store_cookie: &capture_set_cookie/1)
    |> Req.merge(Application.get_env(:market_my_spec, :reddit_req_options, []))
  end

  # Replay the jar's cookies as a `Cookie` header so we present as one
  # returning session instead of a fresh cookieless client each call.
  defp send_stored_cookie(request) do
    case RedditCookieJar.cookie_header() do
      header when is_binary(header) and header != "" ->
        Req.Request.put_header(request, "cookie", header)

      _ ->
        request
    end
  end

  # Capture Reddit's `Set-Cookie` (session/edge cookies) off every response,
  # including 429s — the throttle response is often where the edge cookie is
  # first issued.
  defp capture_set_cookie({request, response}) do
    case Req.Response.get_header(response, "set-cookie") do
      [] -> :noop
      values -> RedditCookieJar.store(values)
    end

    {request, response}
  end

  @doc """
  Returns an anonymous-read ElixirForum (Discourse) client targeting
  `elixirforum.com`.

  Uses the Discourse public JSON API — no authentication required for
  read-only endpoints. The User-Agent identifies the caller per Discourse
  community etiquette.

  Merge `:elixirforum_req_options` from app env so tests can inject the
  ReqCassette plug returned by `with_cassette`.
  """
  @spec elixirforum_client() :: Req.Request.t()
  def elixirforum_client do
    Req.new(
      base_url: "https://elixirforum.com",
      headers: [{"user-agent", @elixirforum_user_agent}],
      retry: :safe_transient,
      max_retries: 2,
      connect_options: [transport_opts: tls_transport_opts()]
    )
    |> Req.merge(Application.get_env(:market_my_spec, :elixirforum_req_options, []))
  end

  # Prefer the bundled castore CA store when available (cross-platform);
  # fall back to OTP 25+ OS-loaded cacerts; finally fall back to no opts
  # so the caller surfaces the underlying mint error.
  defp tls_transport_opts do
    if Code.ensure_loaded?(CAStore) do
      [cacertfile: CAStore.file_path()]
    else
      [cacerts: :public_key.cacerts_get()]
    end
  rescue
    _ -> []
  end

  # Fallback backoff for Req's built-in `:safe_transient` retry (which covers
  # 429). Req passes the *retry count* (a 0-based integer) here — NOT the
  # response — so this function cannot read headers, and must not try to
  # (doing so raises a FunctionClauseError that escapes the request).
  #
  # We don't need the header anyway: Req already honors a `Retry-After`
  # response header natively (see Req.Steps.get_retry_delay/3, which calls
  # Req.Response.get_retry_after/1 before consulting this function). So this
  # is only the no-`Retry-After` path: a linear backoff (1s, then 2s) capped
  # at @retry_delay_cap_ms so a retry can't push the call past the
  # orchestrator's per-venue task timeout. The token bucket, not the retry,
  # is what actually keeps us under Reddit's limit.
  @retry_delay_cap_ms 2_000

  defp reddit_retry_delay(retry_count) when is_integer(retry_count) do
    min(1_000 * (retry_count + 1), @retry_delay_cap_ms)
  end

  # Retry policy for Reddit. Crucially we do NOT retry 429: the anonymous RSS
  # IP has such a small request allowance that retrying a rate-limited call
  # just spends more of the budget and deepens the throttle (measured live
  # 2026-06-12 — retrying turned 5 throttled venues into 15 requests, all 429).
  # A 429 should fail fast, surface the "Rate limited" notice, and let the
  # token bucket pace the *next* attempt. We still retry genuine transient
  # failures (network errors, 5xx) since those aren't the IP's fault.
  defp reddit_retry(_request, %Req.Response{status: 429}), do: false

  defp reddit_retry(_request, %Req.Response{status: status})
       when status in [408, 500, 502, 503, 504],
       do: true

  defp reddit_retry(_request, %Req.Response{}), do: false
  defp reddit_retry(_request, exception) when is_exception(exception), do: true
  defp reddit_retry(_request, _other), do: false
end
