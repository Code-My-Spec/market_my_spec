# MarketMySpec.ProblemDiscovery.Pipeline

Stage orchestration. Per stage (Gather / Cluster / Score / Red-team / Board) reads its upstream artifacts, runs the stage logic, persists outputs. Enforces additive Gather (per-saved-search), in-place reclassification on Score reruns, overwrite-no-history semantics across the board (story 743).

## Type

module

## Dependencies

- MarketMySpec.ProblemDiscovery.Frame
- MarketMySpec.ProblemDiscovery.JobPosting
- MarketMySpec.ProblemDiscovery.Candidate
- MarketMySpec.ProblemDiscovery.PaidJobSignal
- MarketMySpec.ProblemDiscovery.RedTeamVerdict
- MarketMySpec.ProblemDiscovery.Source
- MarketMySpec.ProblemDiscovery.Embeddings
- MarketMySpec.ProblemDiscovery.Clustering
- MarketMySpec.ProblemDiscovery.Board
