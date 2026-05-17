# Qa Story Brief

## Tool

web (Vibium MCP browser tools for LiveView flows; mix run for seed setup and verification)

## Auth

Run the seed script to get a fresh magic-link URL:

```
cd /Users/johndavenport/Documents/github/market_my_spec && PORT=4007 mix run priv/repo/qa_seeds.exs
```

Copy the magic-link URL printed under "Journey 1-3 user (individual account)" and navigate to it in Vibium to sign in without an email round-trip. The token is single-use — re-run the seed script if it has been consumed.

For cross-account isolation testing (Account B cannot access Account A), use the agency user magic-link ("Journey 4 user") or client user magic-link ("Journey 5 user") as a second session.

## Seeds

Run the base QA seed script to ensure the three users and their accounts exist:

```
cd /Users/johndavenport/Documents/github/market_my_spec && PORT=4007 mix run priv/repo/qa_seeds.exs
```

Story-specific seed data (threads and touchpoints) must be created live via the Vibium browser session during testing — navigate to the touchpoint list page and verify that seeded data exists. Thread records are required before a touchpoint can be created; if no threads exist, create one by navigating to an account's thread list.

Use the printed account ID from the seed output to build URLs of the form `/accounts/<account_id>/touchpoints`.

## What To Test

### Scenario 1 — Touchpoints index loads for authenticated user

Navigate to `/accounts/<account_id>/touchpoints` after signing in with the QA magic-link. Expect the page to load with the "Touchpoints" heading and a state-filter tab bar (All / Staged / Posted / Abandoned). Expected: `data-test="state-filter-tabs"` is present and all four tabs are visible.

### Scenario 2 — Empty state shows placeholder message

With no touchpoints seeded, the table should display the "No touchpoints found." placeholder. Expected: `data-test="touchpoints-empty"` is visible in the table body.

### Scenario 3 — Touchpoint Show page loads with all fields

If a touchpoint exists (either seeded by a prior session or created through iex/seeds), navigate to `/accounts/<account_id>/touchpoints/<touchpoint_id>`. Expect: `data-test="touchpoint-state"` shows the state (staged/posted/abandoned), polished body textarea is present, and the "Angle" section is shown when the touchpoint has an angle.

### Scenario 4 — Mark Posted form is present for staged/abandoned touchpoints

On the TouchpointLive.Show page for a staged touchpoint: verify that `data-test="mark-posted-form"` is visible with a URL input and a "Mark Posted" button. For a posted touchpoint this form should be hidden.

### Scenario 5 — Mark Posted form rejects submission without a comment URL

On a staged touchpoint's Show page, click "Mark Posted" without filling in the URL field. Expect an error flash ("Could not mark as posted") or an inline validation error. The touchpoint's state should remain "staged".

### Scenario 6 — Mark Posted form succeeds with a valid comment URL

On a staged touchpoint's Show page, fill `[data-test='mark-posted-form']` comment_url input with `https://www.reddit.com/r/elixir/comments/test123/` and submit. Expect a success flash "Touchpoint marked as posted" and the state badge to update to "posted". The "Mark as Posted" form section should disappear (per the `:if={@touchpoint.state != :posted}` guard).

### Scenario 7 — Abandon action transitions state to abandoned

On a staged touchpoint's Show page, click `data-test="abandon-button"`. Expect flash "Touchpoint abandoned" and the state badge to update to "abandoned". The Abandon button should disappear (per the `:if={@touchpoint.state != :abandoned}` guard).

### Scenario 8 — State filter tabs filter the touchpoints list

On the touchpoints index, click the "Staged" tab (`data-test="filter-staged"`). Expect the URL to update to `?state=staged` and the table to show only staged touchpoints (or empty state). Repeat for "Posted" and "Abandoned". Click "All" to return to the full list.

### Scenario 9 — Touchpoint row links to Show page

On the touchpoints index, click a touchpoint row (`data-test="touchpoint-row-<id>"`). Expect navigation to `/accounts/<account_id>/touchpoints/<touchpoint_id>` and the Show page renders.

### Scenario 10 — Delete action removes the touchpoint

On a touchpoint's Show page, click the Delete button (`data-test="open-delete-modal"`) to open the confirm modal, then confirm deletion. Expect a flash "Touchpoint deleted", navigation away from the Show page, and the touchpoint no longer appearing in the index list.

### Scenario 11 — State badge classes match state values

On the touchpoints index, verify the state badge for a staged touchpoint has the `badge-info` class, for a posted touchpoint has `badge-success`, and for an abandoned touchpoint has `badge-ghost`.

### Scenario 12 — Cross-account access returns not_found (via LiveView redirect)

Sign in as a second account user (agency user from seeds). Attempt to navigate to a touchpoint URL belonging to the QA user's account (e.g. `/accounts/<qa_account_id>/touchpoints/<touchpoint_id>`). Expect a redirect to `/accounts` with an error flash ("Touchpoint not found" or "Account not found").

### Scenario 13 — Angle field appears on Show page when present

Navigate to the Show page of a touchpoint that was staged with an angle value. Verify `data-test="touchpoint-angle"` is visible and shows the angle text.

### Scenario 14 — Abandoning preserves angle and body

On the Show page of a touchpoint with a non-nil angle, click Abandon. After the state changes to "abandoned", refresh or re-navigate to the same Show page. Verify the angle text and polished body text are still present (no destructive data loss).

## Result Path

`.code_my_spec/qa/716/result.md`
