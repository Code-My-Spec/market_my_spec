# MarketMySpec.ProblemDiscovery.Candidate

Cluster output: groups JobPostings into a problem cluster. Carries a pgvector(1536) centroid (mean of member embeddings, used for cross-rerun identity stability), an agent-provided label, and an aggregated score computed from member PaidJobSignals. belongs_to Frame; has_many JobPosting via membership; has_many PaidJobSignal; has_one RedTeamVerdict.

## Type

schema

## Dependencies

- MarketMySpec.ProblemDiscovery.Frame
- MarketMySpec.ProblemDiscovery.JobPosting
