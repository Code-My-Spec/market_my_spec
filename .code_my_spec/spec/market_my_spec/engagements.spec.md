# MarketMySpec.Engagements

Account-scoped engagement-finder domain. Owns venues (which subreddits/forum categories to search per source), threads (ingested + normalized OP+comment trees), touchpoints (saved comment records after post-back), and per-account source credentials (encrypted OAuth tokens for posting). Source behaviour with adapter implementations (Reddit, ElixirForum) defines per-source search, thread fetch, post, and identifier validation. Search and Posting modules orchestrate fan-out across enabled venues and UTM-embedded post-back respectively.

## Type

context

## Dependencies

- MarketMySpec.Users
- MarketMySpec.Accounts
- MarketMySpec.Agents
- MarketMySpec.Linter

## Components

- MarketMySpec.Engagements.Venue (schema): Per-account venue record — source, identifier, weight, enabled flag
- MarketMySpec.Engagements.VenuesRepository (module): Account-scoped CRUD for venues with source-adapter validation
- MarketMySpec.Engagements.Thread (schema): Ingested thread record — source, normalized OP+comment tree, raw payload
- MarketMySpec.Engagements.ThreadsRepository (module): Thread persistence with freshness-window caching
- MarketMySpec.Engagements.Touchpoint (schema): Saved post-back record — comment URL, polished body, link target
- MarketMySpec.Engagements.TouchpointsRepository (module): Touchpoint persistence and retrieval
- MarketMySpec.Engagements.Source (behaviour): Callback contract for per-source adapters
- MarketMySpec.Engagements.Source.Reddit (module): Reddit source adapter
- MarketMySpec.Engagements.Source.ElixirForum (module): ElixirForum (Discourse) source adapter
- MarketMySpec.Engagements.HTTP (module): Req client factory shared by source adapters (User-Agent, base URL, cassette injection)
- MarketMySpec.Engagements.Search (module): Parallel fan-out search across enabled venues
- MarketMySpec.Engagements.Posting (module): UTM-embedded post-back orchestrator
- MarketMySpec.Engagements.SavedSearch (schema): Account-scoped saved-search recipe — name (unique per account), Google-style query string, many-to-many venues, per-source wildcards
- MarketMySpec.Engagements.SavedSearchVenue (schema): Join table for SavedSearch ↔ Venue many-to-many
- MarketMySpec.Engagements.SavedSearchesRepository (module): Account-scoped CRUD plus run_saved_search/2 which resolves the recipe and delegates to Engagements.Search.search/3

## Functions

- search/3 — fans out keyword query across enabled venues; delegates to Engagements.Search
- post_comment/4 — embeds UTM-tracked link into body and creates a Touchpoint via Posting + TouchpointsRepository
- list_venues/2 — lists venues for the account, optionally filtered by source; delegates to VenuesRepository
- create_venue/2 — persists a new venue; delegates to VenuesRepository
- update_venue/3 — updates a venue by id (account-scoped); delegates to VenuesRepository
- delete_venue/2 — deletes a venue by id (account-scoped); delegates to VenuesRepository
- list_saved_searches/1 — lists saved searches preloaded with venues; delegates to SavedSearchesRepository
- get_saved_search/2 — fetches one saved search by id (account-scoped, preloaded); delegates to SavedSearchesRepository
- create_saved_search/2 — persists a new SavedSearch (requires name + query + venue selector); delegates to SavedSearchesRepository
- update_saved_search/3 — updates a SavedSearch (account-scoped); delegates to SavedSearchesRepository
- delete_saved_search/2 — deletes a SavedSearch (account-scoped); delegates to SavedSearchesRepository
- run_saved_search/2 — resolves recipe (linked venues + wildcard-expanded enabled venues) and runs search orchestrator; delegates to SavedSearchesRepository
- get_or_fetch_thread/3 — returns cached Thread when fresh, otherwise fetches from source adapter and persists; delegates to ThreadsRepository
- get_thread_by_id/2 — fetches Thread by UUID (account-scoped); delegates to ThreadsRepository
- list_threads/1 — lists account threads ordered by fetched_at desc; delegates to ThreadsRepository
- set_thread_synopsis/3 — overwrites the thread synopsis on every call (used by stage_response so the agent can iterate); blank/nil is a no-op; delegates to ThreadsRepository.set_synopsis
- get_touchpoint_by_id/2 — fetches single Touchpoint by id (account-scoped); delegates to TouchpointsRepository
- create_touchpoint/2 — persists a new Touchpoint; delegates to TouchpointsRepository
- create_staged_touchpoint/2 — persists a staged Touchpoint (no comment_url/posted_at required); delegates to TouchpointsRepository
- list_touchpoints/1 — lists account touchpoints ordered by posted_at desc; delegates to TouchpointsRepository
- list_touchpoints/2 — same as /1 with `:state` filter and `:preload` opts; delegates to TouchpointsRepository
- update_touchpoint/3 — transitions Touchpoint state (single function shared by LiveView form and update_touchpoint MCP tool); delegates to TouchpointsRepository
- delete_touchpoint/2 — hard-deletes a Touchpoint (no soft-delete); delegates to TouchpointsRepository
- list_source_credentials/1 — returns enabled source credentials for an account (v1 returns `[]`)
- upsert_source_credential/3 — creates or updates OAuth credential for an account+source (v1 returns `{:error, :not_implemented}`)
