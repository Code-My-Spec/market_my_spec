# MarketMySpecWeb.SearchLive

Admin LiveViews for managing saved searches — list, create, edit, delete, and run-from-row. Mirrors the existing VenueLive admin pattern. Account-scoped via current_scope; visiting another account's URL redirects with "Account not found".

## Type

live_context

## Dependencies

- MarketMySpec.Engagements

## Liveviews

- MarketMySpecWeb.SearchLive.Index — account-scoped saved-search admin at /accounts/:id/searches with inline create/edit/delete and per-row "Run now" action

## Components

None
