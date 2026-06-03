# MarketMySpec.Skills.ProblemDiscovery

Problem-discovery skill: guides the agent through the entire 5-stage pipeline (Frame composition, Gather, Cluster review, Score, Red-team, Board), invoking the ProblemDiscovery MCP tools at each stage. Ships alongside MarketMySpec.Skills.MarketingStrategy as a peer skill. Frame composition uses Sales-Safari-style vocabulary audits and supports probe-mode Gather rounds. Cluster review walks the agent through the 3-pass refinement (describe pain → consolidate/split → label). See architecture/decisions/problem-discovery-skill.md.

## Type

context
