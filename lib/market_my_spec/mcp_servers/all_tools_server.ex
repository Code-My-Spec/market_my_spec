defmodule MarketMySpec.McpServers.AllToolsServer do
  @moduledoc """
  Aggregate Anubis MCP server exposing every tool across all topics in one
  connection. Mounted at the base `/mcp` endpoint — the convenience surface a
  client can point at to get everything without mounting each topic server.

  The per-topic servers remain the canonical, focused surfaces:
  `MarketingStrategyServer` (`/mcp/marketing-strategy`), `EngagementServer`
  (`/mcp/engagement`), `FilesServer` (`/mcp/files`), `ProblemDiscoveryServer`
  (`/mcp/problem-discovery`), `AnalyticsAdminServer` (`/mcp/analytics-admin`).

  When a tool is added to a topic server, add it here too.
  """

  use Anubis.Server,
    name: "marketmyspec",
    version: "1.0.0",
    capabilities: [:tools, :resources]

  # --- Marketing strategy ---
  component(MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview)
  component(MarketMySpec.McpServers.MarketingStrategy.Resources.SkillOrientation)
  component(MarketMySpec.McpServers.MarketingStrategy.Resources.Step)

  # --- Files ---
  component(MarketMySpec.McpServers.Marketing.Tools.ListFiles)
  component(MarketMySpec.McpServers.Marketing.Tools.ReadFile)
  component(MarketMySpec.McpServers.Marketing.Tools.WriteFile)
  component(MarketMySpec.McpServers.Marketing.Tools.EditFile)
  component(MarketMySpec.McpServers.Marketing.Tools.DeleteFile)

  # --- Engagement: venues / searches / threads / touchpoints ---
  component(MarketMySpec.McpServers.Engagements.Tools.AddVenue)
  component(MarketMySpec.McpServers.Engagements.Tools.ListVenues)
  component(MarketMySpec.McpServers.Engagements.Tools.UpdateVenue)
  component(MarketMySpec.McpServers.Engagements.Tools.RemoveVenue)
  component(MarketMySpec.McpServers.Engagements.Tools.CreateSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.ListSearches)
  component(MarketMySpec.McpServers.Engagements.Tools.UpdateSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.DeleteSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.RunSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.SearchEngagements)
  component(MarketMySpec.McpServers.Engagement.Tools.GetThread)
  component(MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints)
  component(MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint)
  component(MarketMySpec.McpServers.Engagements.Tools.DeleteTouchpoint)
  component(MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint)
  component(MarketMySpec.McpServers.Engagements.Tools.StageResponse)

  # --- Problem discovery ---
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.ListFrames)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.CreateFrame)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.GetFrame)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.UpdateFrame)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.RunGather)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.ListCandidates)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.ListPostingsForCandidate)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.LabelCandidate)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.MergeCandidates)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.SplitCandidate)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.SetPainDescriptor)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.RedTeamCandidate)
  component(MarketMySpec.McpServers.ProblemDiscovery.Tools.GetBoard)
  component(MarketMySpec.McpServers.ProblemDiscovery.Resources.SkillOrientation)
  component(MarketMySpec.McpServers.ProblemDiscovery.Resources.Step)
  component(MarketMySpec.McpServers.ProblemDiscovery.Resources.Research)

  # --- Analytics admin ---
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ListCustomDimensions)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.GetCustomDimension)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateCustomDimension)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateCustomDimension)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ArchiveCustomDimension)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ListCustomMetrics)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateCustomMetric)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.GetCustomMetric)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateCustomMetric)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ArchiveCustomMetric)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.ListKeyEvents)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.CreateKeyEvent)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.UpdateKeyEvent)
  component(MarketMySpec.McpServers.AnalyticsAdmin.Tools.DeleteKeyEvent)
end
