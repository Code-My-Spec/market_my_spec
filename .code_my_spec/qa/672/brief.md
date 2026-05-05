# QA Story Brief: 672 — Sign Up And Sign In With Google

## Tool

Vibium MCP browser tools for all UI/LiveView routes. curl for checking redirect status codes on controller routes.

## Auth

Run the seed script to create a QA user and get a magic-link URL:

```
mix run priv/repo/qa_seeds.exs
```

The script prints a magic-link URL like `http://localhost:4007/users/log-in/<token>`. Replace port 4007 with 4008 (the active dev server port) when navigating:

```
http://localhost:4008/users/log-in/<token>
```

Navigate to that URL in Vibium to sign in without email. Token is single-use and expires in 20 minutes — re-run seeds if expired.

## Seeds

```
mix run priv/repo/qa_seeds.exs
```

Creates `qa@marketmyspec.test` (user id 1, confirmed), prints a magic-link sign-in URL.

No additional seed data needed for this story — scenarios test the OAuth flow entry points and UI presence, not integration database records.

## Setup Notes

The active dev server is on **port 4008** (not 4007 — the QA plan's 4007 entry is stale; dotenvy port issue means server binds 4008 when started without explicit PORT). Verify before testing:

```
curl -o /dev/null -w "%{http_code}" http://127.0.0.1:4008/users/log-in
```

Should return 200. The seed script magic-link URL will say port 4007 — manually replace with 4008.

The `/integrations/oauth/:provider` routes are in a separate scope with `:require_authenticated_user` applied at the plug level (not a `live_session`). Unauthenticated requests redirect to login.

## What To Test

### Scenario 1: Google sign-in button present on login page (Criterion 5679)

1. Navigate to `http://localhost:4008/users/log-in`
2. Capture screenshot of the login page
3. Verify whether a `[data-test='google-sign-in']` element is present
4. If not present, this is a bug — the login page must have a Google sign-in option per the BDD spec

**Expected:** An element with `data-test="google-sign-in"` exists on the login page.

### Scenario 2: OAuth redirect to Google (Criterion 5679)

1. Sign in via magic-link (navigate to the URL from seeds, substituting port 4008)
2. Once authenticated, navigate to `http://localhost:4008/integrations`
3. Capture screenshot of integrations page
4. Look for a "Connect" link for Google
5. Click the Connect link for Google (or navigate to `http://localhost:4008/integrations/oauth/google` directly)
6. Observe redirect — should go to `accounts.google.com` (or an error if credentials not configured)
7. Capture screenshot of the redirect destination or error

**Expected:** Browser is redirected toward Google's authorization endpoint (accounts.google.com). If Google OAuth credentials are not configured, an error flash may appear on redirect — document this as a QA/config issue, not a code bug.

### Scenario 3: Access denied callback (Criterion 5680)

1. Sign in via magic-link (if not already signed in from Scenario 2)
2. Navigate to `http://localhost:4008/integrations/oauth/callback/google?error=access_denied`
3. Capture screenshot of the result
4. Verify: redirect goes to `/integrations` and an error flash is shown
5. Check the flash message contains "denied" or "access" (case-insensitive)

**Expected:** User is redirected to `/integrations` with an error flash explaining the denial. The `IntegrationsController.callback/2` handles `error` param and calls `format_oauth_error/2`.

### Scenario 4: Integrations page after denied consent (Criterion 5680 recovery)

1. After the redirect from Scenario 3 lands on `/integrations`
2. Verify the page renders normally and the user can still see available integrations (Google still available to connect)
3. Capture screenshot

**Expected:** Integrations page shows Google in "Available" providers with a Connect button. User can re-attempt.

### Scenario 5: Missing sub claim handling (Criterion 5682 — source code review)

This scenario requires a mocked HTTP response from Google, which is not achievable through browser automation without test stubs. Verify via source code inspection:

1. Review `IntegrationsController.callback/2` — it calls `Integrations.handle_callback/5`
2. Review the Integrations context's callback handling for missing sub claim
3. If the code rejects a missing `sub` claim and returns an error flash, document as pass (code review)
4. If the code does not validate sub presence, document as a bug

**Expected:** The `Integrations.handle_callback/5` function validates that a `sub` claim is present in Google's token response and rejects callbacks without it.

### Scenario 6: Email change + same sub resolution (Criterion 5681 — source code review)

Same limitation — requires mocked Google HTTP response. Verify via source code inspection:

1. Review how `Integrations.handle_callback/5` stores and looks up integration records
2. Check whether the lookup uses `sub` (stable) or `email` (can change)
3. If the integration record is keyed on `sub`, document as pass (code review)
4. If keyed on email, document as a bug

**Expected:** Integration records are keyed on Google's `sub` claim so email changes don't break the link.

## Result Path

`.code_my_spec/qa/672/result.md`
