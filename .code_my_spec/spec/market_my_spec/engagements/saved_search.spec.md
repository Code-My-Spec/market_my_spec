# MarketMySpec.Engagements.SavedSearch

Account-scoped saved-search record. Fields: account_id (FK), name (string, unique per account), query (string, Google-style with quoted phrases / AND / OR / negation). Has a many-to-many with Venue via SavedSearchVenue join, plus a separate `source_wildcards` collection (list of source atoms) so a saved search can select "all enabled venues of source X" where supported. Lifecycle is recipe-only — no run history is persisted.

## Type

schema
