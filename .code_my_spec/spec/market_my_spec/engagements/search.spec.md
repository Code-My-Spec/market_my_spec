# MarketMySpec.Engagements.Search

Engagement search orchestrator. Reads the account's enabled venues per source via VenuesRepository, fans out to each Source.search/2 in parallel, deduplicates results, ranks by venue weight × per-source signal, and returns a unified candidate list. Failing sources degrade gracefully — other sources still return results and the failure is reported in the response envelope.

## Type

module

## Dependencies

- MarketMySpec.Engagements.VenuesRepository
- MarketMySpec.Engagements.Source

## Functions

- search/2 — fans out search across all enabled venues in parallel, deduplicates and ranks results, returns unified candidate list with per-source failure envelope
