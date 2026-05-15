# MarketMySpecWeb.SearchLive.Index

Account-scoped saved-search admin at /accounts/:id/searches. Lists saved searches with name, query, venue count, and a "Run now" action per row. Inline form to create/edit a search — name, Google-syntax query string, venue picker (multi-select against the account's enabled venues), and per-source "all of this source" wildcard checkboxes where supported. Clicking "Run now" calls Engagements.run_saved_search/2 and renders the candidate list inline. Cross-account access redirects to /accounts with "Account not found".

## Type

liveview
