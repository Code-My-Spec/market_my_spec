# QA Brief: Story 673 — Sign Up And Sign In With GitHub

## Tool

web (Vibium MCP browser tools) for UI/LiveView pages; curl for route probing.

## Auth

Run seeds to get a magic-link URL, then substitute the port from 4007 to 4008 (current server):

```
mix run priv/repo/qa_seeds.exs
# Outputs: http://localhost:4007/users/log-in/<token>
# Use: http://localhost:4008/users/log-in/<token>
```

Navigate to the magic-link URL in the browser to create an authenticated session without needing email delivery.

## Seeds

```
mix run priv/repo/qa_seeds.exs
```

Creates `qa@marketmyspec.test` (confirmed, id=1) and prints a magic-link sign-in URL.
Re-run between test sessions as tokens are single-use and expire in 20 minutes.

## What To Test

### Scenario 1 — GitHub sign-in button visible on login page (Criterion 5685)

1. Navigate to `http://localhost:4008/users/log-in`
2. Check that an element with `data-test="github-sign-in"` is present on the page
3. Expected: GitHub sign-in button is visible alongside the Google sign-in button
4. Capture screenshot

### Scenario 2 — GitHub OAuth flow initiation (Criterion 5685, continued)

1. Probe `http://localhost:4008/auth/github` with curl: `curl -sS -o /dev/null -w "%{http_code}" http://localhost:4008/auth/github`
2. Expected: 302 redirect (either to GitHub or back to login with flash if creds missing)
3. Verify the route exists and is wired (not 404)

### Scenario 3 — Cancel GitHub authorization recovers cleanly (Criterion 5686)

1. Sign in as the seeded QA user via magic-link URL (port 4008)
2. Probe the integrations OAuth cancellation: `curl -sS -L -o /dev/null -w "%{http_code}" "http://localhost:4008/integrations/oauth/callback/github?error=access_denied"` (should redirect to /integrations)
3. Navigate to `http://localhost:4008/integrations` in browser after the cancellation path
4. Expected: user is redirected to `/integrations`, an error flash message containing "denied" or "access" is shown
5. Capture screenshot

### Scenario 4 — Integrations page shows GitHub as available (Criterion 5685 / happy path)

1. Sign in as seeded QA user via magic-link URL (port 4008)
2. Navigate to `http://localhost:4008/integrations`
3. Verify GitHub appears as an available integration with a Connect button
4. Capture screenshot

### Scenario 5 — Callback with missing GitHub env vars behavior (INFO)

1. Probe `http://localhost:4008/auth/github` directly
2. Expected: if `GITHUB_CLIENT_ID`/`GITHUB_CLIENT_SECRET` are not set, the controller rescues and flashes an error, then redirects to login — NOT a 500 error
3. Confirm the error handling path is graceful

## Setup Notes

- The active dev server is on port **4008** (port 4007 returns 404 for `/auth/github`, indicating stale code)
- The login page currently has a Google sign-in button (`data-test="google-sign-in"`) but the BDD spec (criterion 5685) asserts `data-test="github-sign-in"` — this button may be missing; verify on the actual page
- Criterion 5686 tests `/integrations/oauth/callback/github?error=access_denied` (authenticated route) redirecting to `/integrations`; criterion 5685 tests `/auth/github` (public route) behavior
- GitHub OAuth env vars (`GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`) may not be set in dev; a graceful error is expected — file a LOW/QA issue if the button click results in a crash rather than a user-friendly message
- Screenshots save to `~/Pictures/Vibium/<basename>` — copy to `.code_my_spec/qa/673/screenshots/` after capture

## Result Path

`.code_my_spec/qa/673/result.md`
