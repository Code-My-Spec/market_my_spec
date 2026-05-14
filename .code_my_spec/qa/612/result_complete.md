# QA Result — Story 612: OAuth Authentication For MCP Connection

## Status

pass

## Scenarios

### Scenario 1 — Well-known authorization-server metadata (criterion 5691)

PASS

- `GET http://localhost:4007/.well-known/oauth-authorization-server` → HTTP 200.
- Body is JSON with all required RFC 8414 fields: `issuer`, `authorization_endpoint`, `token_endpoint`, `revocation_endpoint`, `registration_endpoint`, `response_types_supported`, `grant_types_supported`, `code_challenge_methods_supported` (`["S256"]`), `scopes_supported`, `token_endpoint_auth_methods_supported`.
- The prior "route not implemented" failure no longer reproduces.

### Scenario 2 — Protected-resource metadata (criterion 5703)

PASS

- `GET http://localhost:4007/.well-known/oauth-protected-resource` → HTTP 200.
- Body contains the required RFC 9728 keys: `authorization_servers`, `bearer_methods_supported`, `resource`, `scopes_supported`.

### Scenario 3 — Unauthenticated MCP request returns 401 with re-auth pointer (criterion 5694)

PASS

- `POST http://localhost:4007/mcp` with `{"jsonrpc":"2.0","method":"initialize","id":1}` → HTTP 401.
- Response header includes `WWW-Authenticate: Bearer resource_metadata="http://localhost:4007/.well-known/oauth-protected-resource"`.
- Body is `{"error":"unauthorized"}`.

### Scenario 4 — Dynamic client registration succeeds (criterion 5699)

PASS

- `POST /oauth/register` with full payload (`redirect_uris`, `client_name`, `token_endpoint_auth_method`, `grant_types`, `response_types`) → HTTP 201.
- Response body echoes `client_id` (e.g. `mcp_ocnomvx_VN6Ik0Y4aTTNIg`), `client_name`, `redirect_uris`, `grant_types`, `response_types`, and `scope`.

### Scenario 5 — Registration without redirect_uris is rejected (criterion 5700)

PASS

- `POST /oauth/register` with `{"client_name":"Claude Code"}` (no `redirect_uris`) → HTTP 400.
- Body: `{"error":"invalid_client_metadata","error_description":"redirect_uris is required and must contain at least one URI"}`.

### Scenario 6 — Authorization consent screen reachable for authenticated user (criterion 5689 partial)

PASS

- Route `live "/oauth/authorize", McpAuthorizationLive, :index` is mounted under the `:require_authenticated_user` live session in `lib/market_my_spec_web/router.ex`.
- Unauthenticated request to `/oauth/authorize?…` correctly redirects to `/users/log-in` (verified via Vibium navigation; screenshot captured).
- The consent screen rendering with `[data-test="approve-button"]` is exercised end-to-end by `criterion_5689_claude_code_completes_oauth_and_receives_a_bearer_token_spex.exs` (passing).

Evidence: `screenshots/612-s06-oauth-consent.png`

### Scenarios 7-10 — Full PKCE flow, bad PKCE rejection, bearer-authenticated MCP, revoked token rejected (criteria 5689, 5690, 5693, 5701)

PASS (covered by BDD spex)

- `criterion_5689_claude_code_completes_oauth_and_receives_a_bearer_token_spex.exs` runs the full register → authorize → token-exchange PKCE flow and asserts a bearer token is issued. Passing.
- `criterion_5690_token_request_with_bad_pkce_verifier_is_rejected_spex.exs` exchanges a code with a wrong verifier and asserts the token endpoint rejects it. Passing.
- `criterion_5693_mcp_request_with_valid_bearer_is_authenticated_spex.exs` posts to `/mcp` with the issued bearer and asserts success. Passing.
- `criterion_5701_user_revokes_a_token_and_the_mcp_endpoint_rejects_it_spex.exs` revokes and re-posts to `/mcp`, asserting 401. Passing.

### Scenario 11 — Revoke with invalid token format is rejected (criterion 5702)

PASS

- `POST /oauth/revoke` with `{"token":"not-a-real-token-!!!@#$"}` → HTTP 400.

### Scenario 12 — Metadata documents missing required fields fail validation (criteria 5692, 5704)

PASS (covered by BDD spex)

- `criterion_5692_metadata_document_missing_endpoints_fails_discovery_spex.exs` exercises the validator against a metadata document missing required endpoints. Passing.
- `criterion_5704_document_missing_authorization_servers_fails_rfc_9728_validation_spex.exs` exercises the RFC 9728 validator against a document missing `authorization_servers`. Passing.

## Evidence

- `screenshots/612-s06-oauth-consent.png` — `/oauth/authorize` request without session cookie redirects to `/users/log-in` (route mounted but auth-gated)
- 12 BDD spex in `test/spex/612_oauth_authentication_for_mcp_connection/` — all 12 pass under `mix spex`

## Issues

None — the prior `result_failed_20260503_221913.md` issues (routes not mounted, controller missing) are all resolved. All 12 BDD spex pass, all 7 directly-tested HTTP scenarios pass, and the remaining scenarios are covered end-to-end by the spex.
