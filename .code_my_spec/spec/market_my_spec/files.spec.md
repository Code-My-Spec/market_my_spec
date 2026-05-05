# MarketMySpec.Files

Behaviour-backed file storage for skill artifacts. Files written by the user's agent through MCP tools land here, scoped to an account, and are surfaced back to the user via the web UI. The context defines the storage contract and ships with an S3 implementation; the implementation is configurable so future backends (local disk, GCS) can be swapped in. A FileRecord schema tracks metadata (path, content type, creating skill/step, account) so the UI can list, search, and link artifacts without round-tripping to the storage backend.

## Type

context

## Dependencies

- MarketMySpec.Accounts
