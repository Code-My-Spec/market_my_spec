defmodule MarketMySpec.McpServers.ProblemDiscoveryServer do
  @moduledoc false

  use Anubis.Server,
    name: "problem-discovery",
    version: "1.0.0",
    capabilities: [:tools, :resources]

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
end
