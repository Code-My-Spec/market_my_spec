# QA Brief — Story 731: Install and Pair MMS Agent

## Tool

web (Vibium MCP browser tools — all routes are LiveView in the `:browser` pipeline)

## Auth

Run the seed script to create a QA user and get a magic-link URL:

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
```

Copy the magic-link URL printed under "Journey 1-3 user (individual account)". Navigate to it via Vibium to sign in without email:

```
browser_navigate <magic-link URL from qa_seeds.exs output>
```

This sets the session cookie. All subsequent Vibium browser calls in the same session will be authenticated.

Note: The agents routes (`/agents`, `/agents/pair`) are inside the `require_authenticated_user` live_session with `:require_account_membership`. The QA user must have at least one account — the seed script creates one. If the redirect lands at `/accounts/picker` instead of the target, the user has no default account. Check the seed output.

## Seeds

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
```

Creates/updates:
- `qa@marketmyspec.test` (individual account)
- Prints a single-use magic-link URL (expires in 20 minutes — re-run if stale)

No additional story-specific seeds are needed. The pair flow creates Agent records on approve.

## What To Test

### Scenario 1 — Approval screen renders with agent name and buttons (AC 6477)

1. Sign in via magic-link
2. Navigate to `http://localhost:4007/agents/pair?state=qa-state-1&port=51234&name=qa-mac`
3. Verify the page shows "qa-mac" as the agent name
4. Verify an element with `[data-test='approve-pairing']` is present
5. Verify an element with `[data-test='deny-pairing']` is present
6. Screenshot: approval screen

### Scenario 2 — Approve redirects with token and creates Agent record (AC 6472, 6474, 6475)

1. (Still on the pairing screen from Scenario 1)
2. Click the element with `[data-test='approve-pairing']`
3. The browser will attempt to redirect to `http://localhost:51234/callback?token=...&agent_id=...&user_id=...`. Port 51234 has no listener, so Vibium will show a connection error — that is expected.
4. Capture the redirect URL via `browser_get_url` immediately after click (before error page loads, or inspect what the error page URL shows)
5. Verify the URL starts with `http://localhost:51234/callback`
6. Verify `token` query param is present and non-empty (token delivery, never in HTML — AC 6474)
7. Verify `agent_id` and `user_id` params are present
8. Navigate to `http://localhost:4007/agents` and verify the new agent appears in the list
9. Screenshot: /agents list with new agent

### Scenario 3 — Stale/consumed state token rejected (AC 6476)

1. Navigate back to `http://localhost:4007/agents/pair?state=qa-state-1&port=51234&name=qa-mac` (same `state` as Scenario 1, now consumed)
2. Verify the page shows "Pairing session unavailable"
3. Verify no `[data-test='approve-pairing']` element is present
4. Screenshot: unavailable message

### Scenario 4 — Missing params render invalid-link error (AC 6478)

4a. Navigate to `http://localhost:4007/agents/pair?port=51234&name=qa-mac` (no state param)
   - Verify "Invalid pairing link" renders
   - Verify no `[data-test='approve-pairing']` present

4b. Navigate to `http://localhost:4007/agents/pair?state=qa-state-2&name=qa-mac` (no port param)
   - Verify "Invalid pairing link" renders
   - Screenshot: invalid link error

### Scenario 5 — Anonymous user redirected to sign in (AC 6473)

1. Open a fresh browser session (or clear cookies via browser navigation to a log-out URL first)
2. Navigate to `http://localhost:4007/agents/pair?state=qa-state-anon&port=51234&name=qa-mac`
3. Verify browser is redirected to `/users/log-in` (LiveView on_mount: :require_authenticated redirects before the page renders)
4. Screenshot: sign-in page after anon redirect

### Scenario 6 — Deny flow: redirects with denied=true, no Agent created (AC 6479)

1. Sign back in (re-run seeds if token was consumed)
2. Navigate to `http://localhost:4007/agents/pair?state=qa-state-deny&port=51234&name=qa-mac`
3. Verify approval screen renders
4. Click `[data-test='deny-pairing']`
5. Capture redirect URL — should be `http://localhost:51234/callback?denied=true`
6. Verify `denied=true` param present, NO `token` param
7. Navigate to `http://localhost:4007/agents` and verify no NEW agent was created for this state
8. Screenshot: deny redirect URL (error page showing the correct URL)

### Scenario 7 — Token never in rendered HTML (AC 6474, supplementary check)

1. After Scenario 2 (post-approve), navigate to `http://localhost:4007/agents`
2. Get the page HTML and verify no `token=` substring appears in the rendered HTML
3. This confirms the token is only delivered via redirect URL, never embedded in the page

## Result Path

`.code_my_spec/qa/731/result.md`

## Setup Notes

- The server must be running on port 4007 before tests begin. Start with: `PORT=4007 mix phx.server` (in a separate terminal, or confirm it's already running)
- The `/agents/pair` route requires account membership (not just authentication). The QA seed creates an individual account for `qa@marketmyspec.test` so this should be satisfied automatically.
- Use a unique state param per scenario to avoid consuming tokens across scenarios. The state `qa-state-1` is consumed by Scenario 2 (approve), so Scenario 3 can reuse it to test the consumed-state path.
- The redirect to `http://localhost:51234/callback` will always fail (no listener) — the test artifact is the URL itself, not the HTTP response.
- Screenshots land in `~/Pictures/Vibium/` regardless of the filename directory prefix — copy them to `.code_my_spec/qa/731/screenshots/` after capture.
