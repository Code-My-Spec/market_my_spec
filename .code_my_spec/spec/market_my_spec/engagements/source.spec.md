# MarketMySpec.Engagements.Source

Behaviour contract every engagement source implements. Callbacks: validate_venue/1, search/2 (venues, query → candidate threads), get_thread/2 (venue, thread_id → normalized Thread), post/3 (credential, thread_id, body → comment_url). Lets adapters be swapped and added without touching the orchestrators.

## Type

behaviour

## Dependencies

- MarketMySpec.Engagements.Thread
- MarketMySpec.Engagements.Venue
- MarketMySpec.Engagements.SourceCredential

## Functions

- validate_venue/1 — validates source-specific venue identifier format
- search/2 — searches venues for matching threads given a query string
- get_thread/2 — fetches and normalizes a single thread by venue and platform thread id
- post/3 — posts a comment body using account-scoped credentials and returns the live comment URL
