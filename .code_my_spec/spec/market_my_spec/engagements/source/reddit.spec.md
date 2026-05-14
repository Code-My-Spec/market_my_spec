# MarketMySpec.Engagements.Source.Reddit

Reddit Source adapter. Validates subreddit name format, searches via Reddit's per-subreddit search API, fetches full thread JSON and normalizes into the internal Thread schema (preserving comment hierarchy), and posts comments via the Reddit submit-comment endpoint using account-scoped OAuth credentials.

## Type

module

## Dependencies

- MarketMySpec.Engagements.Source
- MarketMySpec.Engagements.Thread
- MarketMySpec.Engagements.Venue
- MarketMySpec.Engagements.SourceCredential

## Functions

- validate_venue/1 — validates subreddit name format (letters, numbers, underscores, 3-21 chars)
- search/2 — searches subreddit via Reddit per-subreddit search API and returns candidate thread list
- get_thread/2 — fetches full Reddit thread JSON and normalizes into Thread schema preserving comment hierarchy
- post/3 — posts comment via Reddit submit-comment API endpoint using account-scoped OAuth credentials
