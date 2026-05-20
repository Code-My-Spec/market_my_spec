defmodule MarketMySpecAgent.Application do
  @moduledoc """
  OTP application for the locally-installed MMS Agent binary.

  Not booted by the `:market_my_spec` server release — the server's
  Application is `MarketMySpecWeb.Application`. This module is only
  used as `mod:` in the dedicated burrito release for the agent
  binary (see `mix.exs`).
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Persistence for the paired token + agent id.
      MarketMySpecAgent.Auth.Store,

      # Long-lived channel client to MMS. Started even when unpaired —
      # it retries on a slow timer until Auth.Store has credentials.
      MarketMySpecAgent.Channel.Client
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
    argv = MarketMySpecAgent.CLI.burrito_argv()

    case argv do
      [] -> :ok
      _ -> System.halt(MarketMySpecAgent.CLI.main(argv))
    end
  end
end
