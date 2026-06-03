# MarketMySpec.ProblemDiscovery

Problem-discovery feature: takes a founder's fuzzy hypothesis through a 5-stage pipeline (Gather, Cluster, Score, Red-team, Board) over real money-validated job postings. Owns Frame, JobPosting, Candidate, PaidJobSignal, RedTeamVerdict artifacts and the pipeline orchestration that produces them. See architecture/decisions/problem-discovery-clustering.md.

## Type

context

## Dependencies

- MarketMySpec.ProblemDiscovery.Frame
- MarketMySpec.ProblemDiscovery.JobPosting
- MarketMySpec.ProblemDiscovery.Candidate
- MarketMySpec.ProblemDiscovery.PaidJobSignal
- MarketMySpec.ProblemDiscovery.RedTeamVerdict
- MarketMySpec.ProblemDiscovery.Source
- MarketMySpec.ProblemDiscovery.Source.Upwork
- MarketMySpec.ProblemDiscovery.Embeddings
- MarketMySpec.ProblemDiscovery.Clustering
- MarketMySpec.ProblemDiscovery.Pipeline
- MarketMySpec.ProblemDiscovery.Board
- MarketMySpec.Skills.ProblemDiscovery
