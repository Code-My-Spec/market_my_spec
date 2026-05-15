defmodule MarketMySpec.McpServers.MarketingStrategyServer do
  @moduledoc false

  use Anubis.Server,
    name: "marketing-strategy",
    version: "1.0.0",
    capabilities: [:tools, :resources]

  component(MarketMySpec.McpServers.MarketingStrategy.Tools.StartInterview)
  component(MarketMySpec.McpServers.Marketing.Tools.ReadFile)
  component(MarketMySpec.McpServers.Marketing.Tools.WriteFile)
  component(MarketMySpec.McpServers.Marketing.Tools.ListFiles)
  component(MarketMySpec.McpServers.Marketing.Tools.EditFile)
  component(MarketMySpec.McpServers.Marketing.Tools.DeleteFile)
  component(MarketMySpec.McpServers.Marketing.Tools.StageResponse)
  component(MarketMySpec.McpServers.Engagements.Tools.SearchEngagements)
  component(MarketMySpec.McpServers.Engagements.Tools.AddVenue)
  component(MarketMySpec.McpServers.Engagements.Tools.ListVenues)
  component(MarketMySpec.McpServers.Engagements.Tools.UpdateVenue)
  component(MarketMySpec.McpServers.Engagements.Tools.RemoveVenue)
  component(MarketMySpec.McpServers.Engagements.Tools.CreateSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.ListSearches)
  component(MarketMySpec.McpServers.Engagements.Tools.RunSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.UpdateSearch)
  component(MarketMySpec.McpServers.Engagements.Tools.DeleteSearch)
  component(MarketMySpec.McpServers.MarketingStrategy.Resources.SkillOrientation)
  component(MarketMySpec.McpServers.MarketingStrategy.Resources.Step)
end
