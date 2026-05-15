# Qa Story Brief

## Tool

web (Vibium MCP browser tools for LiveView surface)

## Auth

Run the base seed script to create the QA user and get a magic-link URL:

```
cd /Users/johndavenport/Documents/github/market_my_spec && PORT=4007 mix run priv/repo/qa_seeds.exs
```

Copy the magic-link URL printed for `qa@marketmyspec.test` (Journey 1-3 user). Navigate Vibium to that URL to sign in without email:

```
browser_navigate <magic-link URL from seed output>
```

The user will be logged in as `qa@marketmyspec.test` with their individual account active.

## Seeds

Run the base seed script (idempotent):

```
cd /Users/johndavenport/Documents/github/market_my_spec && PORT=4007 mix run priv/repo/qa_seeds.exs
```

This creates `qa@marketmyspec.test` with a confirmed individual account and a fresh magic-link token. Note the account ID from the seed output — you need it for the `/accounts/:id/searches` URL.

No story-710-specific seed script exists. The LiveView tests create venues and searches through the UI form.

## What To Test

### Scenario 1: Page loads and shows empty state

1. Sign in via magic-link as `qa@marketmyspec.test`
2. Navigate to `/accounts/<account_id>/searches`
3. Verify the "Saved Searches" heading is present (`data-test="searches-table"`)
4. Verify the empty state message appears (`data-test="searches-empty"`: "No saved searches yet. Add one above.")
5. Verify the "Add Search" button is present (`data-test="add-search-button"`)

### Scenario 2: Create a search scoped to a specific venue (maps to criterion 6227)

Before this scenario, the account needs at least one venue. Navigate to `/accounts/<account_id>/venues` and create a Reddit venue with identifier `elixir` if none exists.

1. Navigate to `/accounts/<account_id>/searches`
2. Click "Add Search" button
3. Verify the inline form appears (`data-test="search-form"`)
4. Fill in name: "elixir hiring" (`data-test="search-name-input"`)
5. Fill in query: "elixir hiring" (`data-test="search-query-input"`)
6. Select the reddit/elixir venue in the venue picker (`data-test="search-venue-picker"`)
7. Click Save (`data-test="search-form-submit"`)
8. Verify the form closes and the search row appears in the table with name "elixir hiring"
9. Verify the flash message "Search saved successfully" appears
10. Verify venue count column shows 1

### Scenario 3: Create a search with source wildcard only (maps to criterion 6228)

1. Navigate to `/accounts/<account_id>/searches`
2. Click "Add Search"
3. Fill name: "all elixirforum"
4. Fill query: "elixir testing"
5. Do NOT select any specific venues
6. Check the "ElixirForum (all)" source wildcard checkbox (`data-test="wildcard-elixirforum"`)
7. Click Save
8. Verify the search row appears in the table
9. Verify venue count column shows 0 (wildcard has no specific venues)

### Scenario 4: Reject creating search with no venue selection (maps to criterion 6229)

1. Navigate to `/accounts/<account_id>/searches`
2. Click "Add Search"
3. Fill name: "no venues search"
4. Fill query: "anything"
5. Do NOT select any venues or source wildcards
6. Click Save
7. Verify an error message appears (`data-test="search-form-error"`) — should indicate venue_ids validation failure
8. Verify the search is NOT added to the table

### Scenario 5: Edit an existing search

1. Find the "elixir hiring" row in the searches table
2. Click the "Edit" button (`data-test="search-edit-<id>"`)
3. Verify the form populates with the existing name, query, and selected venues
4. Change name to "elixir hiring updated"
5. Click Save
6. Verify the row updates in the table

### Scenario 6: Run a search from the row

1. Find any search row in the table
2. Click "Run now" (`data-test="search-run-<id>"`)
3. Verify a results section appears below the row (`data-test="search-results-<id>"`)
4. Verify it shows either "No candidates found." or a list of candidates
5. This verifies the run_saved_search delegates to the orchestrator (criterion 6232, 6235 — empty results are expected for scaffold adapters)

### Scenario 7: Delete a search

1. Find the "all elixirforum" row (from scenario 3)
2. Click "Delete" (`data-test="search-delete-<id>"`)
3. Verify the row is removed from the table
4. Verify flash message "Search deleted" appears

### Scenario 8: Cross-account access is blocked (maps to criterion 6234)

1. Still signed in as `qa@marketmyspec.test`
2. Try navigating to `/accounts/99999/searches` (a non-existent account ID)
3. Verify the user is redirected to `/accounts` with an error flash "Account not found"

### Scenario 9: Duplicate name within same account is rejected (maps to criterion 6231)

1. Create a search named "test duplicate" with any venue
2. Attempt to create a second search named "test duplicate" on the same account
3. Verify an error appears in the form

## Result Path

`.code_my_spec/qa/710/result.md`

## Setup Notes

The `/accounts/:id/searches` route requires authentication and a valid account ID. The account ID is printed by the seed script or can be found by navigating to `/accounts` after sign-in and clicking through to an account.

Venue data is needed to test venue-scoped searches (Scenario 2). If the QA account has no venues, create one first via `/accounts/<account_id>/venues` before testing searches.

Run search results will likely be empty (no candidates) for all scenarios — v1 source adapters are read-only scaffold adapters. Empty results are expected behavior, not a bug (per story context).

The MCP tool surface (create_search, list_searches, run_search, etc.) is not tested via browser — BDD specs in `test/spex/710_*/` cover that surface via direct repository calls. This QA brief covers the LiveView admin UI surface only.
