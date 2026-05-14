# QA Story Brief — Story 707: Polish dictated draft, stage with UTM-tracked link, copy-and-track from UI

## Tool

web (Vibium MCP browser tools) for UI/LiveView testing; `mix spex` for automated spex validation.

## Auth

Seed the QA user and get a magic-link token:

```
mix run priv/repo/qa_seeds.exs
```

The script prints a magic-link URL like `http://localhost:4008/users/log-in/<token>`. Navigate to that URL in the browser to sign in as `qa@marketmyspec.test`. The QA user has an account with ID visible after login.

Alternatively, the seed script also prints credentials for `qa-agency@marketmyspec.test` and `qa-client@marketmyspec.test`. Any of these can be used to access the ThreadLive.Show view.

## Seeds

Run the base seed script before testing:

```
mix run priv/repo/qa_seeds.exs
```

For story 707, the seed script creates enough data (QA user + account). The thread and touchpoint data must be seeded via story-specific means — see the spex fixtures for how test data is constructed. The dev server must be running: `PORT=4008 mix phx.server`.

Story-707-specific seed (if needed for manual browser testing — creates a thread and staged touchpoint):

```
mix run priv/repo/qa_seeds_696.exs
```

## What To Test

### 1. Automated spex validation (all 12 criteria)

Run `mix spex` and verify all 249 tests pass (0 failures). This covers:

- Criterion 6200 — `StageResponse.execute/2` returns a staged touchpoint id
- Criterion 6201 — UTM link embedded in staged body for Reddit source
- Criterion 6202 — Staged drafts visible in UI on ThreadLive.Show
- Criterion 6203 — Copy to clipboard button present on thread show page
- Criterion 6204 — Thread show page provides mark_posted form
- Criterion 6205 — Touchpoint state: staged on `stage_response`, page shows staged section
- Criterion 6206 — `Reddit.post/3` and `ElixirForum.post/3` both return `{:error, :posting_not_supported}`
- Criterion 6207 — `StageResponse.execute/2` returns non-empty response with id
- Criterion 6208 — `Posting.embed_utm_link/3` returns body with `utm_source=reddit&utm_medium=engagement`
- Criterion 6209 — Thread show page renders staged drafts section
- Criterion 6210 — Thread show page renders with staged drafts section
- Criterion 6211 — Touchpoint fixture preserves polished body unchanged

### 2. Browser UI testing — ThreadLive.Show

After signing in via the magic-link URL:

a. Navigate to `/accounts` to find the account ID
b. Navigate to `/accounts/:account_id/threads` to find any thread IDs (may be empty — scaffold)
c. Navigate to `/accounts/:account_id/threads/:thread_id` directly using a known thread ID from seeds
d. Verify the page renders "Thread ID: ..." with the "Staged Drafts" divider
e. Verify the "No staged drafts yet." empty state when no touchpoints exist
f. Verify the page structure: card with thread info, "Staged Drafts" section

### 3. Touchpoint display (if touchpoints exist in dev DB)

If touchpoints are present in the dev DB:

a. The staged touchpoint body appears in a textarea
b. The status badge shows "staged"
c. A "Copy to clipboard" button is present with the touchpoint id in `data-content`
d. The mark_posted form appears with an input for the comment URL and a "Mark Posted" button
e. Submitting the form with a URL transitions the touchpoint to "posted" status
f. Posted touchpoints show the comment URL under "Posted: <url>"

### 4. Code-level verification

- Verify `StageResponse` scaffold at `lib/market_my_spec/mcp_servers/marketing/tools/stage_response.ex` returns `staged: true, touchpoint_id: "staged-<thread_id>-<int>"`
- Verify `Posting.embed_utm_link/3` at `lib/market_my_spec/engagements/posting.ex` appends `?utm_source=reddit&utm_medium=engagement&utm_campaign=engagement&utm_content=<thread_id>` for Reddit threads
- Verify `Reddit.post/3` and `ElixirForum.post/3` return `{:error, :posting_not_supported}`
- Verify `ThreadLive.Show` at `lib/market_my_spec_web/live/thread_live/show.ex` renders the full scaffold

### 5. Known limitations to note

- `StageResponse.execute/2` is a scaffold — it does NOT persist to the database. It generates an in-memory `staged-<thread_id>-<int>` id. Real DB persistence is pending.
- `ThreadLive.Show` always starts with `@touchpoints = []` (no DB query). Touchpoints are only in-memory after the `mark_posted` event.
- `Touchpoint` schema has `status` field missing from the struct definition (the schema doesn't declare it; it's only used as a map field in `mark_posted` handler).
- The `mark_posted` event handler does an `Enum.map` over `socket.assigns.touchpoints` matching `tp.id == tp_id` — since the list is always empty on mount, this is currently a no-op.

## Result Path

`.code_my_spec/qa/707/result.md`
