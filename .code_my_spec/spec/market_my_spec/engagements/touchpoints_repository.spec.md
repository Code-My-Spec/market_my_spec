# MarketMySpec.Engagements.TouchpointsRepository

Account-scoped touchpoint persistence. create_touchpoint/2, list_touchpoints/1 (per account), list_touchpoints_for_thread/2.

## Type

module

## Dependencies

- MarketMySpec.Engagements.Touchpoint

## Functions

- create_touchpoint/2 — persists a new Touchpoint record for an account
- list_touchpoints/1 — returns all touchpoints for an account ordered by posted_at descending
- list_touchpoints_for_thread/2 — returns all touchpoints for a specific thread within an account
