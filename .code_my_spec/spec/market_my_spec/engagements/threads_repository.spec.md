# MarketMySpec.Engagements.ThreadsRepository

Account-scoped thread persistence + freshness-window cache. get_or_fetch_thread/3 (account, source, thread_id) returns the cached thread if fresh; otherwise calls Source.get_thread/2, persists the normalized + raw forms, and returns it. list_threads/1 returns recently fetched threads per account.

## Type

module

## Dependencies

- MarketMySpec.Engagements.Thread
- MarketMySpec.Engagements.Source

## Functions

- get_or_fetch_thread/3 — returns cached Thread if within freshness window; otherwise fetches from source, persists, and returns
- list_threads/1 — returns recently fetched threads for an account ordered by fetched_at descending
