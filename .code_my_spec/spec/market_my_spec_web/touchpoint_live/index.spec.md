# MarketMySpecWeb.TouchpointLive.Index

Touchpoint list for the active account, filterable by state (:staged | :posted | :abandoned). Each row shows polished_body excerpt, angle, state, comment_url (if set), inserted_at, and thread title. Click a row → navigates to TouchpointLive.Show. Reads via Engagements.list_touchpoints (account-scoped). Per story 716 R6 (list_touchpoints ordered newest first with full metadata).

## Type

liveview

## Dependencies

- MarketMySpec.Engagements
