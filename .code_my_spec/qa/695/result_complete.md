# QA Result: Story 695 — Agency Subdomain Assignment and Host Routing

## Status

pass

## Scenarios

### Scenario 1: Owner claims an unused subdomain

Pass.

Signed in as `qa-agency@marketmyspec.test` (agency owner of "QA Agency") via magic-link. Navigated to `/agency/settings`. The subdomain form (`[data-test='subdomain-form']`) rendered with an empty subdomain field. Filled in `qa-agency-test` and clicked "Save subdomain". Flash message "Subdomain saved" appeared. Reloaded `/agency/settings` and confirmed the field was prefilled with `qa-agency-test`.

Evidence: `695-04-agency-settings-initial.png`, `695-05-subdomain-saved.png`

### Scenario 2: Owner sets a well-formed subdomain (rename)

Pass.

From the settings page (with subdomain already set to `qa-agency-test`), filled `qa-agency-new` and submitted. Flash "Subdomain saved" confirmed. The agency subdomain in the database updated to `qa-agency-new` (verified via Elixir query).

Evidence: `695-08-subdomain-changed.png`

### Scenario 3: Owner submits a malformed subdomain

Pass.

Submitted `INVALID_SUBDOMAIN!` (uppercase + special chars). The form rendered two inline validation errors:
- "must start with a letter"
- "must contain only lowercase letters, numbers, and hyphens"

No flash was shown; the subdomain was not saved.

Evidence: `695-06-malformed-subdomain.png`

### Scenario 4: Owner attempts to claim a reserved subdomain

Pass.

Submitted `admin` (a reserved name). Form rendered error: "is reserved and cannot be used". Subdomain not saved.

Evidence: `695-07-reserved-subdomain.png`

### Scenario 5: Owner attempts to claim a subdomain already taken

Pass.

Created a second agency (`Second QA Agency`, owner `qa-agency2@marketmyspec.test`). Signed in as the second agency owner and navigated to `/agency/settings`. Attempted to claim `qa-agency-new` (already held by QA Agency). Form rendered error: "is already taken". Subdomain not saved.

Evidence: `695-10-second-agency-settings.png`, `695-11-duplicate-subdomain-error.png`

### Scenario 6: Individual account attempts to claim a subdomain

Pass.

Tested at the model layer via `HostResolver.claim_subdomain/2` against the individual-typed "QA Client Account". Result: `{:error, changeset}` with error `"is only available for agency accounts"`. The changeset's `validate_agency_type/1` correctly rejects non-agency accounts. No UI path to this form exists for individual accounts (they are blocked at the live session level by `require_agency_account`).

### Scenario 7: Member-role user attempts to change the subdomain

Pass.

Added `qa@marketmyspec.test` as a `:member` role on QA Agency. Signed in and navigated to `/agency/settings`. The `Authorization.authorize(:manage_account, ...)` check in the Settings `mount` returned `false` and redirected to `/agency` (the dashboard). Member cannot access the settings form at all.

Evidence: `695-13-member-role-redirected.png`

### Scenario 8: Visitor hits an active agency subdomain

Pass.

Using `curl -H "Host: qa-agency-new.marketmyspec.com"` against `http://localhost:4008/` returned HTTP 200. The response body contained "QA Agency" (the agency name), confirming the `AgencyHost` plug resolved the subdomain, set `current_agency_id` in the session, and the layout rendered the agency name in the navbar.

Apex response for same path did not contain "QA Agency".

### Scenario 9: Visitor lands on the apex domain

Pass.

`curl -H "Host: marketmyspec.com"` against `/` returned HTTP 200. The response body did not contain "QA Agency" — correct, no agency scope on apex.

Evidence: `695-14-apex-homepage.png`

### Scenario 10: Visitor hits a never-claimed subdomain

Pass.

`curl -H "Host: ghost-qa.marketmyspec.com"` returned HTTP 302 with `location: https://marketmyspec.com/`. No agency holds that subdomain; plug correctly redirects to apex.

### Scenario 11: Visitor hits a previously-claimed subdomain after rename (former subdomain)

Pass.

The agency previously held `qa-agency-test`, then renamed to `qa-agency-new`. Requesting `curl -H "Host: qa-agency-test.marketmyspec.com"` returned HTTP 302 with `location: https://marketmyspec.com/`. The plug treats former subdomains identically to never-claimed subdomains — no stale-history tracking, just a live DB lookup that returns `:none`.

### Scenario 12: API call hits the apex domain

Pass.

`curl -H "Host: marketmyspec.com" http://localhost:4008/.well-known/oauth-authorization-server` returned HTTP 200 with a JSON OAuth metadata body. API endpoints are served on the apex.

### Scenario 13: API call hits an agency subdomain

Pass.

`curl -H "Host: qa-agency-new.marketmyspec.com" http://localhost:4008/.well-known/oauth-authorization-server` returned HTTP 302, not 200. The `AgencyHost` plug's `handle_api_path/1` redirected the API path to apex. Same result for `/mcp`.

MCP on apex returned HTTP 401 (auth required, not a redirect).

### Scenario 14: Spex suite

Pass.

All 165 spex across the full suite pass (including all 695-story scenarios). Verified with `mix spex` (no PORT needed — test env runs on a separate port). Output: `165 tests, 0 failures`.

## Evidence

- `.code_my_spec/qa/695/screenshots/695-01-agency-login.png` — initial navigation to magic-link URL
- `.code_my_spec/qa/695/screenshots/695-02-magic-link-confirm.png` — confirmation page for magic-link
- `.code_my_spec/qa/695/screenshots/695-03-logged-in-home.png` — logged in as agency owner
- `.code_my_spec/qa/695/screenshots/695-04-agency-settings-initial.png` — agency settings page, empty subdomain
- `.code_my_spec/qa/695/screenshots/695-05-subdomain-saved.png` — subdomain saved flash confirmation
- `.code_my_spec/qa/695/screenshots/695-06-malformed-subdomain.png` — validation errors for malformed input
- `.code_my_spec/qa/695/screenshots/695-07-reserved-subdomain.png` — reserved name rejection
- `.code_my_spec/qa/695/screenshots/695-08-subdomain-changed.png` — subdomain rename confirmation
- `.code_my_spec/qa/695/screenshots/695-09-second-agency-login-state.png` — second agency login flow
- `.code_my_spec/qa/695/screenshots/695-10-second-agency-settings.png` — second agency settings form
- `.code_my_spec/qa/695/screenshots/695-11-duplicate-subdomain-error.png` — "is already taken" error
- `.code_my_spec/qa/695/screenshots/695-12-individual-user-redirected.png` — individual user redirected from /agency/settings
- `.code_my_spec/qa/695/screenshots/695-13-member-role-redirected.png` — member-role user redirected to /agency dashboard
- `.code_my_spec/qa/695/screenshots/695-14-apex-homepage.png` — apex homepage (no agency scope)

## Issues

None
