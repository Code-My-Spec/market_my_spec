# MarketMySpecWeb.TouchpointLive

Account-scoped touchpoint management surface. Lists touchpoints for the active account (filterable by state — :staged | :posted | :abandoned), opens a single touchpoint with polished_body, angle, state, and comment_url visible. Owns the "mark posted" form (paste live URL + timestamp), the "abandon" action, and the "delete" action. All write actions call into MarketMySpec.Engagements (update_touchpoint/3, delete_touchpoint/2) — the same context functions backing the MCP update_touchpoint and delete_touchpoint tools, so UI and agent surfaces transition state identically (story 716 R5 — unified state transitions).

## Type

live_context

## Dependencies

- MarketMySpec.Engagements
- MarketMySpec.Accounts

## Liveviews

- MarketMySpecWeb.TouchpointLive.Index — account-scoped list of touchpoints filterable by state
- MarketMySpecWeb.TouchpointLive.Show — single-touchpoint detail with mark-posted, abandon, and delete actions

## Components

None
