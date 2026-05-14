# QA Result — Story 611: View MCP Connection Instructions

## Status

pass

## Environment

- Server: `PORT=4007 mix phx.server`
- Date: 2026-05-14
- Seeds: `mix run priv/repo/qa_seeds.exs`
- QA user: `qa@marketmyspec.test`

## Scenarios

### Scenario 1 — Authenticated user sees server URL and install command

PASS

1. Ran `mix run priv/repo/qa_seeds.exs` — received magic-link for `qa@marketmyspec.test`.
2. Navigated to magic-link URL — session cookie set, page shows `qa@marketmyspec.test` in nav.
3. Navigated to `http://localhost:4007/mcp-setup` — page loaded with 200, no redirect.
4. `[data-test="server-url"]` is present and contains `http://localhost:4007/mcp` (ends in `/mcp`).
5. `[data-test="install-command"]` is present and contains `claude mcp add market-my-spec http://localhost:4007/mcp`.
6. `[data-test="oauth-instructions"]` is present and visible.

Evidence: s01-mcp-setup-authenticated.png, s01-mcp-setup-full.png

### Scenario 2 — Page quality gate: server URL and install command are non-empty

PASS

1. Same authenticated session from Scenario 1.
2. `[data-test="server-url"]` text: `http://localhost:4007/mcp` — non-empty, ends in `/mcp`.
3. `[data-test="install-command"]` text: `claude mcp add market-my-spec http://localhost:4007/mcp` — non-empty, contains `claude mcp add`.

### Scenario 3 — Anonymous visitor is bounced to login

PASS

1. Clicked "Log out" in nav — browser redirected to `/` with "Logged out successfully" flash.
2. Navigated to `http://localhost:4007/mcp-setup` without a session cookie.
3. Browser redirected to `http://localhost:4007/users/log-in`.
4. Login page shows flash "You must log in to access this page."

Evidence: s02-anon-redirect-to-login.png

### Scenario 4 — Anonymous request gets no connection details

PASS

1. After logout, navigated to `http://localhost:4007/mcp-setup` (unauthenticated).
2. Response redirected to `/users/log-in`.
3. Page text does NOT contain `/mcp` or `claude mcp add` — only the login form is rendered.
4. No server URL or install command is visible before authentication.

### Scenario 5 — After sign-in, user is returned to /mcp-setup

PASS

1. Navigated to `http://localhost:4007/mcp-setup` while unauthenticated — redirected to `/users/log-in` (return URL stored).
2. Re-ran seeds to get a fresh magic-link token; navigated to the token URL.
3. Clicked "Log me in only this time" on the confirmation page.
4. Browser landed on `http://localhost:4007/mcp-setup` — return URL was correctly preserved and honored.
5. "Welcome back!" flash was shown on the `/mcp-setup` page.

Evidence: s03-post-signin-return-to-mcp-setup.png

## Evidence

- `.code_my_spec/qa/611/screenshots/s01-mcp-setup-authenticated.png` — mcp-setup page viewport, authenticated
- `.code_my_spec/qa/611/screenshots/s01-mcp-setup-full.png` — mcp-setup full page, showing server URL, install command, and step 3
- `.code_my_spec/qa/611/screenshots/s02-anon-redirect-to-login.png` — login page after anonymous redirect from /mcp-setup
- `.code_my_spec/qa/611/screenshots/s03-post-signin-return-to-mcp-setup.png` — /mcp-setup after sign-in return redirect

## Issues

None. All five scenarios passed.
