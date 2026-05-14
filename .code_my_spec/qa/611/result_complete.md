# QA Result — Story 611: View MCP Connection Instructions

## Status

pass

## Scenarios

### Scenario 1 — Authenticated user sees server URL and install command (criterion 5695)

PASS

- Ran seeds, signed in as `qa@marketmyspec.test` via magic-link, clicked "Keep me logged in on this device".
- Navigated to `/mcp-setup`. Page rendered with sidebar nav and three-step instructions.
- HTML inspection confirmed all three required selectors:
  - `[data-test="install-command"]` → `claude mcp add market-my-spec http://localhost:4007/mcp`
  - `[data-test="server-url"]` → `http://localhost:4007/mcp`
  - `[data-test="oauth-instructions"]` → "Claude Code will open a browser for you to authorize the connection. Server URL:"
- Three additional troubleshooting `details` sections are present (`port-conflict-troubleshooting`, `oauth-troubleshooting`, `mcp-connection-troubleshooting`).

Evidence: `screenshots/611-s01-mcp-setup-authenticated.png`

### Scenario 2 — Server URL and install command non-empty (criterion 5696)

PASS

- Same authenticated session as Scenario 1.
- `[data-test="server-url"]` text is `http://localhost:4007/mcp` (non-empty, ends in `/mcp`).
- `[data-test="install-command"]` text is `claude mcp add market-my-spec http://localhost:4007/mcp` (non-empty, contains `claude mcp add`).

### Scenario 3 — Anonymous visitor is bounced to login (criterion 5697)

PASS

- `curl -sS -o /dev/null -w "%{redirect_url}\n%{http_code}\n" http://localhost:4007/mcp-setup` → HTTP 302 with `Location: http://localhost:4007/users/log-in`.

### Scenario 4 — Anonymous request gets no connection details (criterion 5698)

PASS

- Anonymous `curl -L http://localhost:4007/mcp-setup` follows the redirect to `/users/log-in`.
- Final response body contains 0 occurrences of `claude mcp add` and 0 occurrences of `localhost:4007/mcp` (grep confirmed).
- The redirect status code itself (302) prevents the body from being meaningful pre-follow.

### Scenario 5 — After sign-in, user is returned to /mcp-setup (covered by BDD spex)

PASS (via BDD spex)

- Covered programmatically by the `UserAuth.log_in_user/3` return-to behavior tested in `test/market_my_spec_web/user_auth_test.exs` and the `criterion_5697_anonymous_visitor_is_bounced_through_sign-in_to_mcp-setup_spex.exs` end-to-end flow which exercises the return-to mechanism.

## Evidence

- `screenshots/611-s01-mcp-setup-authenticated.png` — authenticated `/mcp-setup` view showing all three required `data-test` selectors

## Issues

None — the prior `result_failed_20260503_214217.md` issues no longer reproduce on current code. All 4 BDD spex pass and all browser/curl scenarios pass.
