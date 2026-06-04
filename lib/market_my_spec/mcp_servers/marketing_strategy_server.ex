defmodule MarketMySpec.McpServers.MarketingStrategyServer do
  @moduledoc """
  Anubis MCP server for the marketing-strategy topic: the interview tool and its
  guiding resources. Mounted at `/mcp/marketing-strategy`.

  Engagement tools (venues, searches, threads, touchpoints) now live in
  `MarketMySpec.McpServers.EngagementServer`, and generic file operations in
  `MarketMySpec.McpServers.FilesServer` — separate topics, separate endpoints.
  The base `/mcp` (`MarketMySpec.McpServers.AllToolsServer`) still exposes every
  tool for a single connection.
  """

  use Anubis.Server,
    name: "marketing-strategy",
    version: "1.0.0",
    capabilities: [:tools, :resources]

  component(MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview)
  component(MarketMySpec.McpServers.MarketingStrategy.Resources.SkillOrientation)
  component(MarketMySpec.McpServers.MarketingStrategy.Resources.Step)
end
