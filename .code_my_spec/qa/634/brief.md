# QA Brief: Story 634 — MCP Setup Guide

## Tool

Vibium MCP browser tools (all routes are LiveView behind `:require_authenticated_user`)

## Auth

Run seeds first to get a fresh magic-link token:

```
mix run priv/repo/qa_seeds.exs
```

Copy the printed magic-link URL and replace the port from 4007 to 4008 (current running server).
Navigate to the magic-link URL in the browser to sign in without an email round-trip.

Example: if seeds prints `http://localhost:4007/users/log-in/TOKEN`, navigate to
`http://localhost:4008/users/log-in/TOKEN`.

## Seeds

```
mix run priv/repo/qa_seeds.exs
```

Creates/ensures user `qa@marketmyspec.test` and prints a magic-link sign-in URL.
Token is single-use and expires in 20 minutes — re-run if expired.

## What To Test

### Scenario 1: Three-step guide visible top-to-bottom (Criterion 5705)

1. Sign in via magic-link token at `http://localhost:4008/users/log-in/TOKEN`
2. Navigate to `http://localhost:4008/mcp-setup`
3. Verify page loads (not redirected back to login)
4. Verify install step is present — look for `[data-test='install-step']`
5. Verify OAuth sign-in step is present — look for `[data-test='oauth-step']`
6. Verify first-interview step is present — look for `[data-test='interview-step']`
7. Verify install command is present — look for `[data-test='install-command']` containing text matching `claude mcp add`
8. Verify server URL is present — look for `[data-test='server-url']`
9. Capture screenshot of the full setup guide page

### Scenario 2: Expected-result verification element present (Criterion 5706)

1. On the same `/mcp-setup` page (authenticated)
2. Verify `[data-test='expected-result']` element is present
3. Verify the element contains text matching one of: `connected`, `success`, `working`, or `installed`
4. Capture screenshot showing the expected-result element

### Scenario 3: Port-conflict troubleshooting block present (Criterion 5707)

1. On the same `/mcp-setup` page (authenticated)
2. Verify `[data-test='port-conflict-troubleshooting']` element is present
3. Verify the element contains text mentioning `port`
4. Capture screenshot of the troubleshooting section

### Scenario 4: All three troubleshooting blocks present (Criterion 5708)

1. On the same `/mcp-setup` page (authenticated)
2. Verify `[data-test='port-conflict-troubleshooting']` is present
3. Verify `[data-test='oauth-troubleshooting']` is present
4. Verify `[data-test='mcp-connection-troubleshooting']` is present
5. Capture screenshot of troubleshooting blocks section

### Scenario 5: Unauthenticated redirect

1. In a fresh browser (or after logout), navigate to `http://localhost:4008/mcp-setup`
2. Verify the user is redirected to the login page (302 → `/users/log-in`)

## Result Path

`.code_my_spec/qa/634/result.md`

## Setup Notes

The app server is currently running on port 4008 (not 4007 as shown in the QA plan — port 4007 has a stale server without the `/mcp-setup` route). Verify `/mcp-setup` returns 302 on the target port before testing.

The current `McpSetupLive` source at `lib/market_my_spec_web/live/mcp_setup_live.ex` includes:
- `[data-test='install-command']` on the install code block
- `[data-test='server-url']` on the server URL code block
- `[data-test='oauth-instructions']` on the OAuth step `<li>`

But the BDD specs require these additional `data-test` attributes that are NOT currently in the source:
- `[data-test='install-step']` on the install `<li>`
- `[data-test='oauth-step']` on the OAuth `<li>`
- `[data-test='interview-step']` on the first interview `<li>`
- `[data-test='expected-result']` — expected result verification element
- `[data-test='port-conflict-troubleshooting']`
- `[data-test='oauth-troubleshooting']`
- `[data-test='mcp-connection-troubleshooting']`

These are likely missing from the implementation and will cause test failures. Document all gaps in the result.
