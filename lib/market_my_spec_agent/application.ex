defmodule MarketMySpecAgent.Application do
  @moduledoc """
  OTP application for the locally-installed MMS Agent binary.

  Not booted by the `:market_my_spec` server release — the server's
  Application is `MarketMySpecWeb.Application`. This module is only
  used as `mod:` in the dedicated burrito release for the agent
  binary (see `mix.exs`).
  """

  use Application

  alias MarketMySpec.Engagements.RateLimiter
  alias MarketMySpec.Engagements.Source.RedditCookieJar
  alias MarketMySpecAgent.Auth
  alias MarketMySpecAgent.Channel
  alias MarketMySpecAgent.CLI
  alias MarketMySpecAgent.Reddit.Worker

  @impl true
  def start(_type, _args) do
    # Resolve the --env flag (or MMS_AGENT_ENV) BEFORE building the
    # children list so `Auth.Store.init/1` reads the right credential
    # file on its first call. Doing this any later means the Store
    # caches credentials from the wrong env.
    argv = CLI.burrito_argv()
    {env, _rest} = CLI.parse_env_flag(argv)
    CLI.apply_env_override(env)

    children = [
      # Persistence for the paired token + agent id.
      Auth.Store,

      # Reddit reads run on THIS machine's IP, so this machine owns the
      # rate limit. One request per 60s, matching what Reddit's
      # x-ratelimit-* headers report for anonymous RSS. Registered under
      # the RateLimiter's default name so Reddit.fetch/2 picks it up with
      # no plumbing. The server supervises its own separate instance for
      # its own IP.
      {RateLimiter, buckets: Worker.bucket_config()},

      # Replays Reddit's Set-Cookie across requests so the binary reads as
      # one returning session rather than a cookieless client per call.
      RedditCookieJar,

      # Serializes fetches — one in flight at a time, no exceptions.
      Worker,

      # Long-lived channel client to MMS. Started even when unpaired —
      # it retries on a slow timer until Auth.Store has credentials.
      Channel.Client
    ]

    opts = [strategy: :one_for_one, name: MarketMySpecAgent.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

    # Dispatch the CLI subcommand inline (Burrito-friendly) once the
    # supervision tree is up. For the long-running `server` mode we
    # just let the Application run forever.
    spawn(fn -> dispatch_cli() end)
    {:ok, sup}
  end

  defp dispatch_cli do
    argv = CLI.burrito_argv()

    case argv do
      [] -> :ok
      _ -> System.halt(CLI.main(argv))
    end
  end
end
