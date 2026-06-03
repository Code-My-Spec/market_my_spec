# MarketMySpec.McpServers.ProblemDiscovery

Anubis MCP server namespace exposing the ProblemDiscovery feature to the agent. Hosts tools that orchestrate the pipeline (Gather, Cluster, Score, Red-team) and tools the agent uses to refine clusters (label, merge, split). Follows the existing McpServers.Engagements / McpServers.MarketingStrategy pattern.

## Type

context

## Dependencies

- MarketMySpec.ProblemDiscovery
- MarketMySpec.Skills.ProblemDiscovery
