# MarketMySpec.ProblemDiscovery.JobPosting

Raw posting fetched by Gather, one per Source.search result row. Carries title, description, money signals (total_spent, hire_rate), and a pgvector(1536) embedding computed once on insert via Embeddings. belongs_to Frame and SavedSearch (provenance).

## Type

schema

## Dependencies

- MarketMySpec.ProblemDiscovery.Frame
