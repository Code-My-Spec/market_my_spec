# Qa Story Brief

Story 708 — Configure venues per source for engagement search.

## Tool

web (Vibium MCP browser tools for all LiveView pages)

## Auth

Run seeds to get a fresh magic-link token:

```
PORT=4008 mix run priv/repo/qa_seeds.exs
```

Copy the magic-link URL printed under "Journey 1-3 user (individual account)" and navigate to
it in the browser. The QA user email is `qa@marketmyspec.test` and has an individual account
with ID `8b3b25da-7778-4c50-8233-d4d1e7d272c8`.

Navigate the browser to the magic-link URL to sign in without email:

```
http://localhost:4008/users/log-in/<encoded_token>
```

The venues admin page for this account is:

```
http://localhost:4008/accounts/8b3b25da-7778-4c50-8233-d4d1e7d272c8/venues
```

## Seeds

Run the base seed script before testing:

```
PORT=4008 mix run priv/repo/qa_seeds.exs
```

The QA user and account already exist. Seeds are idempotent — re-run to refresh the
magic-link token (single-use, expires in 20 minutes).

## What To Test

### 1. Venue list page renders correctly (criterion 6154)

- Navigate to `/accounts/8b3b25da-7778-4c50-8233-d4d1e7d272c8/venues`
- Verify "Venues" heading is visible
- Verify "Add Venue" button is visible
- Verify the venues table appears (data-test="venues-table")
- Verify the empty state message "No venues configured. Add one above." appears (data-test="venues-empty")
- Capture screenshot of initial state

### 2. Add a Reddit venue (criterion 6155, 6144, 6147)

- Click the "Add Venue" button (data-test="add-venue-button")
- Verify the inline form appears (data-test="venue-form")
- Select "Reddit" from the source dropdown
- Enter "elixir" as the identifier
- Enter "1.5" as the weight
- Click Save
- Verify "elixir" appears in the venue list
- Verify "reddit" source badge appears
- Capture screenshot of venue list with the new entry

### 3. Add an ElixirForum venue (criterion 6145)

- Click "Add Venue" again
- Select "ElixirForum" from the source dropdown
- Enter "phoenix-forum" as the identifier
- Enter "1.0" as the weight
- Click Save
- Verify "elixirforum" source and "phoenix-forum" identifier appear in the list
- Capture screenshot

### 4. Invalid Reddit subreddit name is rejected (criterion 6148, 6140)

- Click "Add Venue"
- Select "Reddit" from the source dropdown
- Enter "ab" as the identifier (too short — subreddit must be 3-21 chars)
- Click Save
- Verify an error message appears (data-test="venue-form-error" or text containing "Invalid")
- Capture screenshot of validation error
- Also test "my-subreddit" (contains hyphen — invalid) to confirm rejection

### 5. Toggle enabled flag (criterion 6156, 6158, 6159)

- With a venue in the list, find the toggle checkbox (data-test="venue-enabled-toggle-{id}")
- Click the toggle to disable the venue
- Verify the checkbox state changes (unchecked means disabled)
- Capture screenshot of disabled state
- Click toggle again to re-enable
- Verify checkbox is checked again

### 6. Remove a venue (criterion 6157)

- Find the Remove button for a venue row (data-test="venue-delete-{id}")
- Click Remove
- Verify the venue disappears from the list
- If it was the last venue, verify empty state "No venues configured" returns
- Capture screenshot of list after removal

### 7. Account scoping — wrong account redirects (criterion 6154 second scenario, 6160, 6161)

- While authenticated as qa@marketmyspec.test, try navigating to the agency account's venues page
- Agency account ID: `fa730842-0dd0-40c7-bd8f-8d1e4158cf34`
- Expected: redirect back to /accounts or a not-found state (NOT the venue list for the agency)
- Capture screenshot of result

### 8. Explore edge cases

- Try adding a venue with an empty identifier — verify error
- Try adding a venue with an empty source — verify error
- Try a 22-character subreddit name (too long) — verify rejection
- Cancel the add form with the Cancel button — verify form hides without adding

## Result Path

`.code_my_spec/qa/708/result.md`

## Setup Notes

The venue LiveView (VenueLive.Index) is noted as a scaffold in the source. The critical
implementation detail: venues are stored in socket assigns (in-memory only during the
LiveView session), NOT persisted to the database via VenuesRepository yet. The handler
creates a map with `System.unique_integer` as the id and appends to `@venues`. This means:

- Venues are not persisted across page reloads
- The MCP tools (AddVenue, ListVenues, etc.) may be scaffold-only
- BDD spex tests use `:scaffold` return tuples as acceptable pass conditions for MCP layer

Test the UI behavior based on what the LiveView actually does (in-memory venue management)
and flag any gaps between implementation and acceptance criteria as issues.
