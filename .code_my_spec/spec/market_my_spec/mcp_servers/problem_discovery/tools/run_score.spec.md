# MarketMySpec.McpServers.ProblemDiscovery.Tools.RunScore

MCP tool: run Score for a Frame. Applies the Frame's money_gate to each JobPosting in each Candidate (rewriting PaidJobSignal.classification in place, no creates/deletes), recomputes Candidate.score. Makes no HTTP requests.

## Type

module

## Dependencies

- MarketMySpec.ProblemDiscovery
