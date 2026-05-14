# MarketMySpec.Engagements.Venue

Per-account venue record. Fields: account_id, source (enum: reddit | elixirforum), identifier (source-typed payload — subreddit name for Reddit, category id + optional tag for ElixirForum), weight (float, ranking multiplier, default 1.0), enabled (boolean, default true).

## Type

schema

## Fields

- account_id — foreign key to Account
- source — enum (reddit | elixirforum), the platform this venue belongs to
- identifier — source-typed venue identifier (subreddit name for Reddit; category id with optional tag for ElixirForum)
- weight — float ranking multiplier applied during search result scoring, default 1.0
- enabled — boolean flag controlling whether this venue is included in searches, default true
