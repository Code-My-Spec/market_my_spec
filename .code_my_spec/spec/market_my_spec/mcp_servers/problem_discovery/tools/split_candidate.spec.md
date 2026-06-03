# MarketMySpec.McpServers.ProblemDiscovery.Tools.SplitCandidate

MCP tool: split one Candidate into multiple, given a partition over its JobPosting members. Recomputes centroids per new group, reassigns PaidJobSignals, drops the original's RedTeamVerdict (the verdict no longer applies to the new partition shape).

## Type

module

## Dependencies

- MarketMySpec.ProblemDiscovery
