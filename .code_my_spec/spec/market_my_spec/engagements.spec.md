# MarketMySpec.Engagements

Account-scoped engagement-finder domain. Owns venues (which subreddits/forum categories to search per source), threads (ingested + normalized OP+comment trees), touchpoints (saved comment records after post-back), and per-account source credentials (encrypted OAuth tokens for posting). Source behaviour with adapter implementations (Reddit, ElixirForum) defines per-source search, thread fetch, post, and identifier validation. Search and Posting modules orchestrate fan-out across enabled venues and UTM-embedded post-back respectively.

## Type

context

## Dependencies

- MarketMySpec.Users
- MarketMySpec.Accounts

## Components

- MarketMySpec.Engagements.Venue (schema): Per-account venue record — source, identifier, weight, enabled flag
- MarketMySpec.Engagements.VenuesRepository (module): Account-scoped CRUD for venues with source-adapter validation
- MarketMySpec.Engagements.Thread (schema): Ingested thread record — source, normalized OP+comment tree, raw payload
- MarketMySpec.Engagements.ThreadsRepository (module): Thread persistence with freshness-window caching
- MarketMySpec.Engagements.Touchpoint (schema): Saved post-back record — comment URL, polished body, link target
- MarketMySpec.Engagements.TouchpointsRepository (module): Touchpoint persistence and retrieval
- MarketMySpec.Engagements.SourceCredential (schema): Per-account-per-source OAuth credentials for posting
- MarketMySpec.Engagements.Source (behaviour): Callback contract for per-source adapters
- MarketMySpec.Engagements.Source.Reddit (module): Reddit source adapter
- MarketMySpec.Engagements.Source.ElixirForum (module): ElixirForum (Discourse) source adapter
- MarketMySpec.Engagements.Search (module): Parallel fan-out search across enabled venues
- MarketMySpec.Engagements.Posting (module): UTM-embedded post-back orchestrator
- MarketMySpec.Engagements.SavedSearch (schema): Account-scoped saved-search recipe — name (unique per account), Google-style query string, many-to-many venues, per-source wildcards
- MarketMySpec.Engagements.SavedSearchVenue (schema): Join table for SavedSearch ↔ Venue many-to-many
- MarketMySpec.Engagements.SavedSearchesRepository (module): Account-scoped CRUD plus run_saved_search/2 which resolves the recipe and delegates to Engagements.Search.search/3

## Functions

- invite_user/4 — not applicable; see child modules for public API
- search/2 — delegates to Engagements.Search
- post_comment/4 — delegates to Engagements.Posting
- list_venues/2 — delegates to VenuesRepository
- create_venue/2 — delegates to VenuesRepository
- update_venue/3 — delegates to VenuesRepository
- delete_venue/2 — delegates to VenuesRepository
- get_or_fetch_thread/3 — delegates to ThreadsRepository
- list_threads/1 — delegates to ThreadsRepository
- create_touchpoint/2 — delegates to TouchpointsRepository
- list_touchpoints/1 — delegates to TouchpointsRepository
- list_source_credentials/1 — lists enabled source credentials for an account
- upsert_source_credential/3 — creates or updates OAuth credential for an account+source
