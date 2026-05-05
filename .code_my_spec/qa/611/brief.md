# QA Brief — Story 611: View MCP Connection Instructions

## Tool

web (Vibium MCP browser tools for LiveView pages)

## Auth

Run the seed script first to create a QA user and generate a magic-link URL:

```
mix run priv/repo/qa_seeds.exs
```

The script prints a magic-link sign-in URL of the form:

```
http://localhost:4007/users/log-in/<encoded_token>
```

Navigate to that URL in the browser to authenticate without email — the session cookie is set on arrival.

## Seeds

```
mix run priv/repo/qa_seeds.exs
```

Creates `qa@marketmyspec.test` (force-confirmed) and a fresh `login` token. Re-run between sessions to get a fresh magic-link token.

## What To Test

### Scenario 1 — Authenticated user sees server URL and install command

1. Run seeds; copy the magic-link URL from the output.
2. Navigate to the magic-link URL to sign in.
3. Navigate to `http://localhost:4007/mcp-setup`.
4. Confirm the page loads (200, no redirect).
5. Confirm an element with `data-test="server-url"` is present and contains a non-empty URL ending in `/mcp`.
6. Confirm an element with `data-test="install-command"` is present and contains the text `claude mcp add`.
7. Confirm an element with `data-test="oauth-instructions"` is present.
8. Capture a screenshot of the page in its initial loaded state.

### Scenario 2 — Page quality gate: server URL and install command are non-empty

1. Same signed-in state from Scenario 1.
2. Read the text of `[data-test="server-url"]` — must not be blank.
3. Read the text of `[data-test="install-command"]` — must not be blank.

### Scenario 3 — Anonymous visitor is bounced to login

1. In a fresh (unauthenticated) browser session, navigate to `http://localhost:4007/mcp-setup`.
2. Confirm the browser is redirected to `/users/log-in` (check URL after navigation).
3. Capture a screenshot of the login page with the redirect in effect.

### Scenario 4 — Anonymous request gets no connection details

1. In a fresh (unauthenticated) session, navigate to `http://localhost:4007/mcp-setup`.
2. The response should redirect (302) to `/users/log-in`.
3. Confirm the redirect response body does NOT contain `/mcp`.
4. Confirm the redirect response body does NOT contain `claude mcp add`.
5. Confirm no connection details are visible before sign-in completes.

### Scenario 5 — After sign-in, user is returned to /mcp-setup

1. Navigate to `http://localhost:4007/mcp-setup` while unauthenticated (stores the return URL).
2. Complete sign-in via the magic-link URL.
3. Confirm the browser lands on `/mcp-setup` after authentication.

## Result Path

`.code_my_spec/qa/611/result.md`
