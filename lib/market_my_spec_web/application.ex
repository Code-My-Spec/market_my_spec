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
        # Chat (streaming LLM chat UI) — supervised task runner for LLM calls
        # so the LiveView never blocks, plus the ETS-backed in-flight registry.
        {Task.Supervisor, name: MarketMySpec.Chat.TaskSupervisor},
        MarketMySpec.Chat.ActiveTasks,
        # ProblemDiscovery Gather — long-running live scrapes against Apify +
        # OpenAI embedding batches blow the MCP gateway timeout when run
        # synchronously. RunGather spawns a Task here and returns immediately;
        # the agent polls GetFrame for artifact counts to track progress.
        # Per-saved-search `gathered_at` marks give crash resume — completed
        # searches skip on the agent's retry.
        {Task.Supervisor, name: MarketMySpec.ProblemDiscovery.GatherSupervisor},
        # MCP servers — mounted via Anubis StreamableHTTP plug in the router.
        # Each server owns its own per-session state (persistent_term) and
        # must be supervised independently, even though they share transport.
        {MarketMySpec.McpServers.AllToolsServer, transport: :streamable_http},
        {MarketMySpec.McpServers.MarketingStrategyServer, transport: :streamable_http},
        {MarketMySpec.McpServers.EngagementServer, transport: :streamable_http},
        {MarketMySpec.McpServers.FilesServer, transport: :streamable_http},
        {MarketMySpec.McpServers.AnalyticsAdminServer, transport: :streamable_http},
        {MarketMySpec.McpServers.ProblemDiscoveryServer, transport: :streamable_http},
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
