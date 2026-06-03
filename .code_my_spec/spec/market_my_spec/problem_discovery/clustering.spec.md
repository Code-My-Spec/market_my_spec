# MarketMySpec.ProblemDiscovery.Clustering

Wraps Scholar.Cluster.KMeans with a deterministic seed and silhouette-based K-selection over K ∈ {3..8}. Pulls JobPosting embeddings for a Frame into Nx tensors, fits, returns clusters with centroids ready to persist as Candidates. Pure in-process compute (no API calls). See architecture/decisions/scholar.md.

## Type

module

## Dependencies

- MarketMySpec.ProblemDiscovery.JobPosting
- MarketMySpec.ProblemDiscovery.Candidate
