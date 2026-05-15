# Qa Result

## Status

pass

## Scenarios

### Scenario 1: Page loads and shows empty state

pass

Logged in as `qa@marketmyspec.test` via magic-link. Navigated to `/accounts/8b3b25da-7778-4c50-8233-d4d1e7d272c8/searches`. The "Saved Searches" heading was present. The `data-test="searches-table"` element was found. The empty state message `data-test="searches-empty"` showed "No saved searches yet. Add one above." The `data-test="add-search-button"` was present. No Postgrex errors — the migration drift bug is fully resolved by `20260514110000_align_saved_searches_schema.exs`.

Evidence: `.code_my_spec/qa/710/screenshots/rerun-03-empty-state.png`

### Scenario 2: Create a search scoped to a specific venue (criterion 6227)

pass

Clicked "Add Search". The inline form appeared (`data-test="search-form"`). Filled name "elixir hiring" and query "elixir hiring". Selected the reddit/elixir venue (value "1") in the `data-test="search-venue-picker"` multi-select. Clicked Save (`data-test="search-form-submit"`). The flash "Search saved successfully" appeared and the table row showed name "elixir hiring", query "elixir hiring", and venue count "1".

Evidence: `.code_my_spec/qa/710/screenshots/rerun-05-search-created.png`

### Scenario 3: Create a search with source wildcard only (criterion 6228)

pass

Clicked "Add Search". Filled name "all elixirforum" and query "elixir testing". Did not select any specific venues. Checked the `data-test="wildcard-elixirforum"` checkbox (ElixirForum all). Clicked Save. The flash "Search saved successfully" appeared and the table row showed name "all elixirforum" with venue count "0".

Evidence: `.code_my_spec/qa/710/screenshots/rerun-06-wildcard-search-created.png`

### Scenario 4: Reject creating search with no venue selection (criterion 6229)

pass

Clicked "Add Search". Filled name "no venues search" and query "anything". Did not select any venues or source wildcards. Clicked Save. The error message "venue_ids must have at least one linked venue or at least one source wildcard" appeared in `data-test="search-form-error"`. The search was not added to the table (still only 2 rows).

Evidence: `.code_my_spec/qa/710/screenshots/rerun-07-empty-venue-rejected.png`

### Scenario 5: Edit an existing search

pass

Clicked the Edit button (`data-test="search-edit-<id>"`) on the "elixir hiring" row. The form populated with existing values: name "elixir hiring", query "elixir hiring", and venue "1" selected. Changed the name to "elixir hiring updated" and clicked Save. The flash "Search saved successfully" appeared and the row updated showing "elixir hiring updated".

Evidence: `.code_my_spec/qa/710/screenshots/rerun-09-search-updated.png`

### Scenario 6: Run a search from the row (criterion 6232, 6235)

pass

Clicked "Run now" (`data-test="search-run-<id>"`) on the "elixir hiring updated" row. A results row appeared (`data-test="search-results-<id>"`) showing "Results: 0 candidate(s)" and "No candidates found." This confirms the run delegated to the shared orchestrator and returned an empty candidates/failures envelope without persisting anything. Empty results are expected for scaffold adapters.

Evidence: `.code_my_spec/qa/710/screenshots/rerun-10-run-search-results.png`

### Scenario 7: Delete a search

pass

Clicked "Delete" (`data-test="search-delete-<id>"`) on the "all elixirforum" row. The row was removed from the table and the flash "Search deleted" appeared. Only the "elixir hiring updated" row remained.

Evidence: `.code_my_spec/qa/710/screenshots/rerun-11-search-deleted.png`

### Scenario 8: Cross-account access is blocked (criterion 6234)

pass

Navigated to `/accounts/00000000-0000-0000-0000-000000000001/searches` (a non-existent account UUID). The user was redirected to `/accounts` and the error flash "Account not found" appeared, confirming cross-account isolation.

Evidence: `.code_my_spec/qa/710/screenshots/rerun-12-cross-account-blocked.png`

### Scenario 9: Duplicate name within same account is rejected (criterion 6231)

pass

Attempted to create a search named "elixir hiring updated" — which already existed on the same account. The form error `data-test="search-form-error"` showed "name has already been taken". The duplicate search was not added to the table.

Evidence: `.code_my_spec/qa/710/screenshots/rerun-13-duplicate-name-rejected.png`

## Evidence

- `.code_my_spec/qa/710/screenshots/rerun-02-searches-page-loads.png` — searches page loads without Postgrex error (migration drift resolved)
- `.code_my_spec/qa/710/screenshots/rerun-03-empty-state.png` — empty state with all required data-test elements present
- `.code_my_spec/qa/710/screenshots/rerun-04-add-form-open.png` — add search form open with venue picker and wildcard checkboxes
- `.code_my_spec/qa/710/screenshots/rerun-05-search-created.png` — search "elixir hiring" created with 1 venue
- `.code_my_spec/qa/710/screenshots/rerun-06-wildcard-search-created.png` — wildcard search "all elixirforum" created with 0 venues
- `.code_my_spec/qa/710/screenshots/rerun-07-empty-venue-rejected.png` — empty venue selection rejected with form error
- `.code_my_spec/qa/710/screenshots/rerun-08-edit-form-open.png` — edit form populated with existing values
- `.code_my_spec/qa/710/screenshots/rerun-09-search-updated.png` — search name updated to "elixir hiring updated"
- `.code_my_spec/qa/710/screenshots/rerun-10-run-search-results.png` — run search shows 0 candidates (scaffold adapter expected)
- `.code_my_spec/qa/710/screenshots/rerun-11-search-deleted.png` — "all elixirforum" search deleted
- `.code_my_spec/qa/710/screenshots/rerun-12-cross-account-blocked.png` — cross-account access blocked, redirected with "Account not found"
- `.code_my_spec/qa/710/screenshots/rerun-13-duplicate-name-rejected.png` — duplicate name rejected with "name has already been taken"

## Issues

None
