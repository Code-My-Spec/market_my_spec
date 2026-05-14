# MarketMySpecWeb.ThreadLive.Index

Lists recently ingested threads for the active account — title, source, venue, fetched_at, touchpoint count. Click a row to open ThreadLive.Show.

## Type

liveview

## Route

`/accounts/:id/threads`

## Dependencies

- MarketMySpec.Engagements

## User Interactions

- Click row — navigates to ThreadLive.Show for the selected thread

## Design

Table listing threads with columns: title (truncated), source badge (Reddit/ElixirForum), venue identifier, time since fetched, and touchpoint count. Empty state shown when no threads have been ingested yet. Uses account-scoped navigation.
