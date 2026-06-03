# MarketMySpec.McpServers.ProblemDiscovery.Tools.SetPainDescriptor

MCP tool: the agent writes a structured pain_descriptor on a JobPosting describing the underlying pain it represents. Used in pass 1 of the 3-pass cluster refinement: agent reads JobPostings in a Candidate, writes per-posting pain descriptors, then uses descriptor similarity to decide MergeCandidates / SplitCandidate calls in pass 2 before LabelCandidate in pass 3.

## Type

module

## Dependencies

- MarketMySpec.ProblemDiscovery
