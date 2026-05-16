defmodule MarketMySpecWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        MarketMySpecWeb.Telemetry,
        MarketMySpec.Repo,
        MarketMySpec.Vault,
        MarketMySpec.Integrations.OAuthStateStore,
        {DNSCluster, query: Application.get_env(:market_my_spec, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: MarketMySpec.PubSub},
        # MCP server — mounted via Anubis StreamableHTTP plug in the router
        {MarketMySpec.McpServers.MarketingStrategyServer, transport: :streamable_http},
        # Start to serve requests, typically the last entry
        MarketMySpecWeb.Endpoint
      ] ++ cloudflare_tunnel_child()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MarketMySpecWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Cloudflare named tunnel for dev. Returns [] when no tunnel config is set
  # (test/prod, or dev with missing creds). Started AFTER the Endpoint so the
  # local origin is already listening when cloudflared connects.
  defp cloudflare_tunnel_child do
    case Application.get_env(:market_my_spec, :cloudflare_tunnel) do
      nil -> []
      opts -> [{ClientUtils.CloudflareTunnel, opts}]
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MarketMySpecWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
