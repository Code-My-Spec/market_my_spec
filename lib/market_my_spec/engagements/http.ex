defmodule MarketMySpec.Engagements.HTTP do
  @moduledoc """
  Req client factories for Engagements source adapters.

  Reddit and Discourse adapters call into this module to get a configured
  `%Req.Request{}` rather than rolling their own. Centralizing here lets:

  - User-Agent / base URL conventions stay consistent across adapters.
  - Tests inject a ReqCassette plug via `:reddit_req_options` / `:discourse_req_options`
    application env (see test/support/reddit_spex_helpers.ex).
  - Future retry / rate-limit / auth changes happen in one place.

  Per knowledge/req-and-cassette-stack.md.
  """

  @reddit_user_agent "market_my_spec/0.1 by /u/johns10davenport"

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
      retry: :safe_transient,
      max_retries: 2,
      retry_delay: &reddit_retry_delay/1
    )
    |> Req.merge(Application.get_env(:market_my_spec, :reddit_req_options, []))
  end

  defp reddit_retry_delay(resp) do
    case Req.Response.get_header(resp, "x-ratelimit-reset") do
      [v | _] -> trunc(String.to_float(v) * 1_000)
      _ -> 1_000
    end
  rescue
    _ -> 1_000
  end
end
