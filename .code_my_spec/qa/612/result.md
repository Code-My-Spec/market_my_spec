# QA Result — Story 612: OAuth Authentication For MCP Connection

## Status

pass

## Environment

- Server: `PORT=4008 mix phx.server` (port 4008)
- Date: 2026-05-14
- Seeds: `mix run priv/repo/qa_seeds.exs`
- QA user: `qa@marketmyspec.test`
- Note: Brief stated routes were not yet implemented — they ARE implemented as of this run. All endpoints respond correctly.

## Scenarios

### Scenario 1: Well-known metadata discovery (criterion 5691)

PASS

- GET `http://localhost:4008/.well-known/oauth-authorization-server`
- HTTP 200, Content-Type: application/json
- Response contains all required fields:
  - `authorization_endpoint`: `http://localhost:4008/oauth/authorize`
  - `token_endpoint`: `http://localhost:4008/oauth/token`
  - `registration_endpoint`: `http://localhost:4008/oauth/register`
  - `revocation_endpoint`: `http://localhost:4008/oauth/revoke`
  - `issuer`: `http://localhost:4008`
  - `code_challenge_methods_supported`: `["S256"]`
  - `scopes_supported`: `["read","write"]`

### Scenario 2: Protected resource metadata (criterion 5703 — RFC 9728)

PASS

- GET `http://localhost:4008/.well-known/oauth-protected-resource`
- HTTP 200, Content-Type: application/json
- Response contains `authorization_servers: ["http://localhost:4008"]`
- Also contains `resource: "http://localhost:4008/mcp"`, `bearer_methods_supported: ["header"]`

### Scenario 3: Unauthenticated MCP request returns 401 with auth pointer (criterion 5703)

PASS

- POST `http://localhost:4008/mcp` with `{"jsonrpc":"2.0","method":"initialize","id":1,"params":{}}`
- HTTP 401 Unauthorized
- `WWW-Authenticate: Bearer resource_metadata="http://localhost:4008/.well-known/oauth-protected-resource"`
- Body: `{"error":"unauthorized"}`

### Scenario 4: Dynamic client registration — valid (criterion 5699)

PASS

- POST `http://localhost:4008/oauth/register` with valid payload including `redirect_uris`
- HTTP 201
- Response contains `client_id` (e.g. `mcp_0KGhqRyIUDf0BKWlbX1USQ`) and echoed `redirect_uris`
- Also returns `client_secret`, `grant_types`, `response_types`, `scope`

### Scenario 5: Client registration without redirect_uris is rejected (criterion 5700)

PASS

- POST `http://localhost:4008/oauth/register` without `redirect_uris`
- HTTP 400
- Response: `{"error":"invalid_client_metadata","error_description":"redirect_uris is required and must contain at least one URI"}`

### Scenario 6: Authorization consent screen visible and functional (criterion 5689 — partial)

PASS

- GET `/oauth/authorize?client_id=...&redirect_uri=...&response_type=code&code_challenge=...&code_challenge_method=S256&state=...&scope=read+write`
- Route is mounted and renders correctly (not 404)
- Page shows "Authorize MCP client" heading and client name
- `[data-test="approve-button"]` is present and visible
- `[data-test="deny-button"]` is present and visible
- Requested scopes (read, write) are listed when `scope` param is provided
- Both Approve and Deny redirect to `redirect_uri` with appropriate query params (approve: `code=...`, deny: `error=access_denied`)

Note: When no `scope` param is passed, "Requested scopes" section renders empty (no list items shown). This is a minor UI defect — the consent screen should show a fallback message or the client's registered scopes when no scope is requested.

Evidence: s01-consent-screen.png (no scope), s02-consent-with-scopes.png, s03-consent-deny-button.png, s04-consent-empty-scopes.png

### Scenario 7: Full PKCE flow — register, authorize, token exchange (criterion 5689)

PASS

- Full flow exercised by spex criterion_5689 (all 249 spex pass, 0 failures)
- Flow: register client (201) → navigate to /oauth/authorize → user approves → redirect with `code` → POST /oauth/token with `code_verifier` → 200 with `access_token` and `token_type: "Bearer"`
- Verified via `mix spex` — criterion 5689 spex passes

### Scenario 8: Bad PKCE verifier is rejected (criterion 5690)

PASS

- Exercised by spex criterion_5690 (all 249 spex pass)
- Token exchange with wrong `code_verifier` returns error, not a valid token

### Scenario 9: Valid bearer token grants MCP access (criterion 5693)

PASS

- Exercised by spex criterion_5693 (all 249 spex pass)
- POST `/mcp` with valid `Authorization: Bearer <token>` header returns 200 (not 401)

### Scenario 10: Revoked token rejected at MCP endpoint (criterion 5701)

PASS

- Exercised by spex criterion_5701 (all 249 spex pass)
- After POST `/oauth/revoke` with a valid token, subsequent MCP requests with that token return 401

### Scenario 11: Revoke with invalid token format (criterion 5702)

PASS (with note)

- POST `http://localhost:4008/oauth/revoke` with `Content-Type: application/x-www-form-urlencoded` body `token=not-a-real-token-!!!@#$`
- HTTP 200, body `{}`
- Note: The brief expected a 400 response. RFC 7009 §2.2 specifies that the server MUST respond with HTTP 200 even for unrecognized or already-revoked tokens to prevent token enumeration. The implementation correctly follows RFC 7009 by returning 200. The brief's expected 400 was incorrect for this RFC-required behavior.
- Note: Sending `Content-Type: application/json` to `/oauth/revoke` returns a `Plug.Parsers.ParseError` (500) — the endpoint only accepts `application/x-www-form-urlencoded`. This is correct per OAuth spec but the error is an unhandled exception rather than a clean 415 Unsupported Media Type.

### Scenario 12: Metadata document field validation (criteria 5692, 5704)

PASS

- `/.well-known/oauth-authorization-server` returns all required RFC 8414 fields: `issuer`, `authorization_endpoint`, `token_endpoint`, `registration_endpoint`
- `/.well-known/oauth-protected-resource` returns required RFC 9728 field `authorization_servers`
- All 249 spex pass including criteria 5692 and 5704 which test internal validation logic

## Evidence

- `.code_my_spec/qa/612/screenshots/s01-consent-screen.png` — consent screen with no scope param (empty scopes list defect visible)
- `.code_my_spec/qa/612/screenshots/s02-consent-with-scopes.png` — consent screen with scope=read+write (read and write listed correctly)
- `.code_my_spec/qa/612/screenshots/s03-consent-deny-button.png` — consent screen showing both Deny and Approve buttons
- `.code_my_spec/qa/612/screenshots/s04-consent-empty-scopes.png` — consent screen empty scopes (confirms defect)

## Issues

### Consent screen shows empty "Requested scopes" when no scope param is provided

#### Severity

LOW

#### Description

When the OAuth authorization request omits the `scope` query parameter, the consent screen renders with an empty "Requested scopes" section — no list items appear between the heading and the Deny/Approve buttons. The user cannot see what access is being granted.

Expected: either show the client's registered default scopes, or show a message like "No specific scopes requested" or fall back to displaying all registered scopes.

Reproduction: navigate to `/oauth/authorize?client_id=<id>&redirect_uri=...&response_type=code&code_challenge=...&code_challenge_method=S256&state=...` (omit `scope` param).

Evidence: s01-consent-screen.png, s04-consent-empty-scopes.png

### /oauth/revoke returns 500 on application/json content-type

#### Severity

LOW

#### Description

POST `/oauth/revoke` with `Content-Type: application/json` triggers a `Plug.Parsers.ParseError` and returns an HTML 500 error page instead of a clean HTTP error. The revoke endpoint only accepts `application/x-www-form-urlencoded` (per OAuth spec), but should return 415 Unsupported Media Type rather than an unhandled exception.

Reproduction: `curl -X POST http://localhost:4008/oauth/revoke -H "Content-Type: application/json" -d '{"token":"any"}'`
