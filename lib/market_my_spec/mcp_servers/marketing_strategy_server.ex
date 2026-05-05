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
  component(MarketMySpec.McpServers.MarketingStrategy.Resources.SkillOrientation)
  component(MarketMySpec.McpServers.MarketingStrategy.Resources.Step)
end
