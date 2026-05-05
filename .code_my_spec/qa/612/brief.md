# QA Brief — Story 612: OAuth Authentication For MCP Connection

## Tool

curl (API endpoints: `/oauth/*`, `/.well-known/*`, `/mcp`) and Vibium MCP browser tools (authorization consent screen LiveView at `/mcp/authorize`)

## Auth

This story tests OAuth endpoints — most are unauthenticated (registration, token, revoke, well-known) or use OAuth bearer tokens. The authorization consent screen at `/mcp/authorize` requires a session-authenticated user.

For the consent screen scenario, seed and sign in via magic link:

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
# Copy the magic-link URL printed by the script
# Navigate Vibium to: http://localhost:4008/users/log-in/<token>
```

## Seeds

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
```

This creates `qa@marketmyspec.test` and prints a magic-link sign-in URL. Run before any browser-authenticated scenario.

## Setup Notes

App is running on port **4008** (PID 1283). The stale server on 4007 (PID 55959) is outside this sandbox — always test against `http://localhost:4008`.

**Known pre-condition:** As of this writing, the following routes are NOT implemented in the router:

- `/oauth/authorize` — OAuth authorization endpoint (GET/POST)
- `/oauth/token` — Token exchange endpoint (POST)
- `/oauth/revoke` — Token revocation endpoint (POST)
- `/oauth/register` — Dynamic client registration (POST)
- `/.well-known/oauth-authorization-server` — RFC 8414 metadata (GET)
- `/.well-known/oauth-protected-resource` — RFC 9728 metadata (GET)
- `/mcp` — MCP JSON-RPC endpoint (POST)

The `McpAuth` context (Token, Authorization, ConnectionInfo) is implemented but there is no `OauthController` or `McpController` wiring these to HTTP routes.

The `McpAuthorizationLive` LiveView is implemented but is NOT mounted in the router (no route for `/mcp/authorize` or `/oauth/authorize`).

Reference implementation: `/Users/johndavenport/Documents/github/code_my_spec/lib/code_my_spec_web/controllers/oauth_controller.ex`

## What To Test

Test each acceptance criterion by probing the relevant HTTP endpoint. Most will fail with 404 because the routes are not yet wired up — document each failure as an issue.

### Scenario 1: Well-known metadata discovery (criterion 5691)

- GET `http://localhost:4008/.well-known/oauth-authorization-server`
- Expected: 200 JSON with `authorization_endpoint`, `token_endpoint`, `registration_endpoint`
- Document actual response code

### Scenario 2: Protected resource metadata (criterion 5703 — RFC 9728)

- GET `http://localhost:4008/.well-known/oauth-protected-resource`
- Expected: 200 JSON with `authorization_servers` key
- Document actual response code

### Scenario 3: Unauthenticated MCP request returns 401 with auth pointer (criterion 5703)

- POST `http://localhost:4008/mcp` with `Content-Type: application/json` body `{"jsonrpc":"2.0","method":"initialize","id":1,"params":{}}`
- Expected: 401 with `WWW-Authenticate: Bearer` header pointing to auth server
- Document actual status and headers

### Scenario 4: Dynamic client registration — valid (criterion 5699)

- POST `http://localhost:4008/oauth/register` with JSON body:
  ```json
  {"redirect_uris":["https://localhost:3000/callback"],"client_name":"Claude Code","token_endpoint_auth_method":"none","grant_types":["authorization_code"],"response_types":["code"]}
  ```
- Expected: 201 JSON with `client_id` and echoed `redirect_uris`
- Document actual response code

### Scenario 5: Client registration without redirect_uris is rejected (criterion 5700)

- POST `http://localhost:4008/oauth/register` with JSON body:
  ```json
  {"client_name":"Claude Code","token_endpoint_auth_method":"none"}
  ```
- Expected: 400 JSON with `error: "invalid_client_metadata"` or `"invalid_request"`
- Document actual response code

### Scenario 6: Authorization consent screen visible and functional (criterion 5689 — partial)

- Navigate Vibium (authenticated) to: `http://localhost:4008/oauth/authorize?client_id=test&redirect_uri=https://localhost:3000/callback&response_type=code&code_challenge=abc&code_challenge_method=S256&state=test`
- Expected: Consent screen rendered with Approve and Deny buttons (`[data-test='approve-button']`)
- Note: This route may not be mounted. If 404, document as missing route.
- Screenshot the consent page or the error state

### Scenario 7: Full PKCE flow — register, authorize, token exchange (criterion 5689)

- Requires dynamic registration, authorization, and token endpoints to all be working
- If registration (Scenario 4) fails, this scenario is blocked — document as blocked

### Scenario 8: Bad PKCE verifier is rejected (criterion 5690)

- Requires full PKCE flow working first (Scenario 7)
- If Scenario 7 is blocked, document as blocked

### Scenario 9: Valid bearer token grants MCP access (criterion 5693)

- Requires full PKCE flow working (Scenario 7) to get a bearer token
- If blocked, document as blocked

### Scenario 10: Revoked token rejected at MCP endpoint (criterion 5701)

- Requires full PKCE flow + revoke endpoint (Scenario 7)
- If blocked, document as blocked

### Scenario 11: Revoke with invalid token format (criterion 5702)

- POST `http://localhost:4008/oauth/revoke` with body `{"token":"not-a-real-token-!!!@#$"}`
- Expected: 400 JSON with error field
- Document actual response code

### Scenario 12: Metadata document missing required fields fails validation (criteria 5692, 5704)

- These criteria test that a metadata document without required endpoints/authorization_servers fails validation — this is internal/context-level logic, not an HTTP endpoint.
- Probe: confirm `McpAuth.ConnectionInfo.authorization_server_metadata()` and `protected_resource_metadata()` return complete maps by checking if the module compiles and its doctests pass.
- `curl http://localhost:4008/.well-known/oauth-authorization-server` — if missing, the validation criteria cannot be tested at the HTTP level.

## Result Path

`.code_my_spec/qa/612/result.md`
