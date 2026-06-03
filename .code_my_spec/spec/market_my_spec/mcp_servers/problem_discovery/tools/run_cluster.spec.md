# MarketMySpec.McpServers.ProblemDiscovery.Tools.RunCluster

MCP tool: run Cluster for a Frame. Reads JobPosting embeddings, fits KMeans, matches new clusters to existing Candidates by centroid cosine similarity (preserving RedTeamVerdicts where IDs match), persists fresh Candidates for unmatched groups.

## Type

module

## Dependencies

- MarketMySpec.ProblemDiscovery
