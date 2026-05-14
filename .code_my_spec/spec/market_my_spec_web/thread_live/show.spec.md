# MarketMySpecWeb.ThreadLive.Show

Single-thread view. Renders the normalized OP + comment tree alongside any touchpoint records (drafts or posted comments) for the thread. Read-only; posting happens via the MCP tool driven by the LLM, not from this view.

## Type

liveview

## Route

`/accounts/:account_id/threads/:thread_id`

## Dependencies

- MarketMySpec.Engagements

## User Interactions

- Back link — returns to ThreadLive.Index

## Design

Two-column layout: left column shows the thread OP body and indented comment tree (rendered from comment_tree jsonb); right column shows a list of touchpoints for this thread (posted comment URL, body excerpt, posted_at). Read-only; no post or draft actions on this view. Uses account-scoped navigation.
