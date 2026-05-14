# MarketMySpec.Engagements.Source.ElixirForum

ElixirForum (Discourse) Source adapter. Validates category id (and optional tag filter), pulls latest topics from category JSON endpoints with optional tag scoping, fetches full topic JSON and normalizes into the internal Thread schema, and posts replies via the Discourse posts endpoint using account-scoped credentials.

## Type

module

## Dependencies

- MarketMySpec.Engagements.Source
- MarketMySpec.Engagements.Thread
- MarketMySpec.Engagements.Venue
- MarketMySpec.Engagements.SourceCredential

## Functions

- validate_venue/1 — validates ElixirForum venue identifier (category id with optional tag)
- search/2 — fetches latest topics from Discourse category JSON endpoints with optional tag scoping
- get_thread/2 — fetches full Discourse topic JSON and normalizes into Thread schema
- post/3 — posts reply via Discourse posts API endpoint using account-scoped credentials
