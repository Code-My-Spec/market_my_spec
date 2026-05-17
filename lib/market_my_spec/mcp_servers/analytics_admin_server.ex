defmodule MarketMySpec.McpServers.AnalyticsAdminServer do
  @moduledoc """
  Anubis MCP server exposing Google Analytics 4 admin operations
  (custom dimensions, custom metrics, key events) to MCP clients.

  Mounted by `MarketMySpecWeb.AnalyticsAdminMcpController` under the
  bearer-authenticated `/mcp/analytics-admin` route. Each tool resolves
  the GA4 property from the caller's active account
  (`scope.active_account.google_analytics_property_id`) and uses the
  user's Google OAuth integration to call the Analytics Admin API.
  """

  use Anubis.Server,
    name: "analytics-admin-server",
    version: "1.0.0",
    capabilities: [:tools]

  # Custom Dimensions
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ListCustomDimensions)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.GetCustomDimension)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateCustomDimension)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateCustomDimension)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ArchiveCustomDimension)

  # Custom Metrics
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ListCustomMetrics)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateCustomMetric)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.GetCustomMetric)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateCustomMetric)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ArchiveCustomMetric)

  # Key Events
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ListKeyEvents)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateKeyEvent)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateKeyEvent)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.DeleteKeyEvent)
end
