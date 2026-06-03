# MarketMySpec.ProblemDiscovery.PaidJobSignal

Score output: per-JobPosting evaluation against the Frame's money_gate. Carries a gate-classification field (gated_in / gated_out) that Score writes; threshold changes rewrite this field rather than creating or deleting records (story 743 rule 8). belongs_to JobPosting and belongs_to Candidate.

## Type

schema

## Dependencies

- MarketMySpec.ProblemDiscovery.JobPosting
- MarketMySpec.ProblemDiscovery.Candidate
