defmodule MarketMySpec.McpServers.EngagementServer do
  @moduledoc """
  Anubis MCP server for the social-engagement topic: venues, saved searches,
  engagement search, threads, and touchpoints. Mounted at `/mcp/engagement`.

  Its own topic, separate from marketing-strategy. The base `/mcp`
  (`MarketMySpec.McpServers.AllToolsServer`) also exposes these tools.
  """

  use Anubis.Server,
    name: "engagement",
    version: "1.0.0",
    capabilities: [:tools]

  # Venues
  component(MarketMySpec.McpServers.Engagements.Tools.AddVenue)
  component(MarketMySpec.McpServers.Engagements.Tools.ListVenues)
  component(MarketMySpec.McpServers.Engagements.Tools.UpdateVenue)
  component(MarketMySpec.McpServers.Engagements.Tools.RemoveVenue)

  # Saved searches
  component(MarketMySpec.McpServers.Engagements.Tools.CreateSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.ListSearches)
  component(MarketMySpec.McpServers.Engagements.Tools.UpdateSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.DeleteSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.RunSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.SearchEngagements)

  # Threads
  component(MarketMySpec.McpServers.Engagement.Tools.GetThread)

  # Touchpoints
  component(MarketMySpec.McpServers.Engagements.Tools.ListTouchpoints)
  component(MarketMySpec.McpServers.Engagements.Tools.UpdateTouchpoint)
  component(MarketMySpec.McpServers.Engagements.Tools.DeleteTouchpoint)
  component(MarketMySpec.McpServers.Engagements.Tools.PolishTouchpoint)
  component(MarketMySpec.McpServers.Engagements.Tools.StageResponse)
end
