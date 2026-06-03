# MarketMySpec.ProblemDiscovery.Source

Pluggable data source contract (story 740). One callback: search(saved_search) :: {:ok, [posting_attrs]} | {:error, term()}. New sources implement this behaviour; Pipeline.Gather dispatches per saved_search.source to the right impl. Insulates Score/Cluster/Red-team from source-specific concerns.

## Type

behaviour

## Dependencies

- MarketMySpec.ProblemDiscovery.JobPosting
