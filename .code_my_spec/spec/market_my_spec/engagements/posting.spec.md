# MarketMySpec.Engagements.Posting

Post-back orchestrator. Embeds the UTM-tracked link into the polished body using a per-source UTM scheme, loads the account's SourceCredential for the source, calls Source.post/3, persists a Touchpoint record on success, and returns the live comment URL. Posting failures (auth expiry, platform error, rate limit) preserve the polished draft and surface a usable error.

## Type

module

## Dependencies

- MarketMySpec.Engagements.Source
- MarketMySpec.Engagements.SourceCredential
- MarketMySpec.Engagements.TouchpointsRepository

## Functions

- post/4 — embeds UTM link into polished body, loads SourceCredential, calls Source.post/3, persists Touchpoint on success, returns comment URL or structured error
