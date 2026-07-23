# OAuth Authentication For MCP Connection

As a user installing the Market My Spec MCP, I want to authenticate via OAuth (the same flow CodeMySpec uses), so the server can identify me without me copying tokens, and revocation/rotation are handled by the OAuth provider rather than a custom token-management UI.

## Meta
- id: d605876e-f1f7-4d14-881e-b4a3333524d2
- number: 612
- status: in_progress
- priority: 1
- component: MarketMySpec.McpAuth.Token
- personas: founder

## Rules

### MCP clients authenticate to MMS via the OAuth 2.1 authorization-code flow with PKCE (S256). The /oauth/authorize endpoint requires a signed-in MMS user — unauthenticated requests are redirected to /users/log-in with the original OAuth params preserved, then bounced back to the consent screen on success. The /oauth/token endpoint validates the code_verifier against the stored code_challenge; mismatch is rejected with invalid_grant.

#### happy: Claude Code completes OAuth and receives a bearer token [cf54611e]
Given a signed-in MMS user with a configured OAuth Application registered in MarketMySpec.MCPAuth
When Claude Code initiates auth-code flow by opening /oauth/authorize?response_type=code&client_id=...&code_challenge=...&code_challenge_method=S256&redirect_uri=...
Then MCPAuthorizationLive renders the consent screen showing the requesting client and scopes
When the user clicks "Approve"
Then MMS issues an auth code, stores the code_challenge with it, and redirects to the client's redirect_uri with the code
When Claude Code POSTs to /oauth/token with grant_type=authorization_code, code, code_verifier, and client_id
Then ex_oauth2_provider verifies SHA-256(code_verifier) equals code_challenge
And returns a bearer access_token (plus refresh_token) scoped to the user
And the access_token is now valid for the MCP endpoint

#### failure: Token request with bad PKCE verifier is rejected [5388c0a3]
Given a valid authorization code that was issued for code_challenge "ABC..."
When a client POSTs /oauth/token with grant_type=authorization_code, that code, but a code_verifier whose SHA-256 hash does NOT equal "ABC..."
Then ex_oauth2_provider returns HTTP 400 with body {"error": "invalid_grant"}
And no access_token is issued
And the auth code is marked consumed so it cannot be retried

### Authorization-server metadata is published at /.well-known/oauth-authorization-server per RFC 8414, listing issuer, authorization_endpoint, token_endpoint, code_challenge_methods_supported=["S256"], grant_types_supported, response_types_supported, and the scopes MCP clients need — so MCP clients auto-discover endpoints without manual configuration in Claude Code.

#### happy: MCP client auto-discovers endpoints via well-known metadata [c06be61b]
Given Claude Code is configured with only the MMS server URL (e.g., http://localhost:4007)
When it issues GET /.well-known/oauth-authorization-server
Then MMS returns 200 with application/json body containing at minimum:
  - issuer matching the server URL
  - authorization_endpoint pointing at /oauth/authorize on the same host
  - token_endpoint pointing at /oauth/token
  - code_challenge_methods_supported including "S256"
  - grant_types_supported including "authorization_code" and "refresh_token"
  - response_types_supported including "code"
And Claude Code uses these values to construct the authorize URL without operator-supplied paths

#### failure: Metadata document missing endpoints fails discovery [a2bf663c]
Given a regression ships /.well-known/oauth-authorization-server returning JSON without authorization_endpoint or token_endpoint
When an MCP client fetches the document and validates required fields per RFC 8414
Then discovery fails
And QA test for /.well-known/oauth-authorization-server returning all required fields catches the regression before merge

### The MCP server resource validates the bearer token on every request and maps it to a MarketMySpec.Users.User. Missing, expired, or revoked tokens return 401 with a WWW-Authenticate header pointing to the auth server's metadata document, so the MCP client knows where to re-auth without copy-pasted instructions.

#### happy: MCP request with valid bearer is authenticated [ab6b09ee]
Given an MCP client holds an unexpired access_token issued for user qa@marketmyspec.test
When it sends a JSON-RPC request to /mcp with header "Authorization: Bearer <token>"
Then MarketMySpec.MCPAuth.Token.validate_bearer returns {:ok, user}
And the request reaches the Anubis MCP plug pipeline with assigns.current_user set
And the JSON-RPC response is returned successfully

#### failure: Expired bearer token returns 401 with re-auth pointer [22ac6713]
Given an MCP client sends a JSON-RPC request to /mcp with header "Authorization: Bearer <expired_token>"
When MarketMySpec.MCPAuth.Token.validate_bearer detects the token's expires_at is in the past
Then the response is HTTP 401
And the response includes header "WWW-Authenticate: Bearer realm=\"MCP\", error=\"invalid_token\", resource_metadata=\"<host>/.well-known/oauth-authorization-server\""
And the body is a JSON-RPC error object describing the auth failure
And no skill resources or tools are exposed

### MCP clients can self-register at POST /oauth/register per RFC 7591 (Dynamic Client Registration) — sending client_name + redirect_uris returns a generated client_id and client_secret. This lets Claude Code complete its first OAuth handshake without an operator pre-creating an OAuth application in MMS.

#### happy: Claude Code self-registers as an OAuth client [94167dab]
Given an MCP client without a pre-existing OAuth application
When it POSTs to /oauth/register with JSON body {"client_name": "Claude Code", "redirect_uris": ["http://127.0.0.1:6444/callback"]}
Then MMS returns HTTP 201 with body containing:
  - client_id starting with "mcp_"
  - client_secret (URL-safe base64, 32 bytes)
  - grant_types including "authorization_code"
  - response_types including "code"
  - scope including "read write"
And a corresponding OAuth Application row exists in MarketMySpec.MCPAuth so subsequent /oauth/authorize requests with that client_id succeed

#### failure: Registration request without redirect_uris is rejected [88f8724f]
Given an MCP client POSTs /oauth/register with no redirect_uris (or an empty array)
When the request reaches MarketMySpec.MCPAuth.register_application
Then the response is HTTP 400
And the body contains {"error": "invalid_client_metadata", "error_description": "..."} listing the missing field
And no OAuth Application row is created

### MMS exposes /oauth/revoke per RFC 7009 so MCP clients or the user can invalidate an access or refresh token immediately. Subsequent MCP requests using a revoked token are rejected with the same 401 + WWW-Authenticate behavior as expired tokens.

#### happy: User revokes a token and the MCP endpoint rejects it [206ed355]
Given a valid access_token "abc123" issued to a client
When the client POSTs /oauth/revoke with body {"token": "abc123"}
Then the response is HTTP 200 with empty body
And the access_token row is marked revoked
When the client subsequently sends an MCP JSON-RPC request with header "Authorization: Bearer abc123"
Then the response is HTTP 401 with WWW-Authenticate header pointing to /.well-known/oauth-authorization-server

#### failure: Revoke request with invalid token format is rejected [241995ad]
Given a client POSTs /oauth/revoke with a malformed body (missing "token" field)
When the request reaches the controller
Then the response is HTTP 400
And the body is {"error": "invalid_request", "error_description": "..."}
And no token state changes

### Protected-resource metadata is published at /.well-known/oauth-protected-resource per RFC 9728, listing resource=<host>/mcp, authorization_servers=[<host>], scopes_supported, and bearer_methods_supported=["header"] — so MCP clients can discover the auth server starting only from the MCP endpoint URL.

#### happy: MCP client discovers auth server from MCP endpoint URL [3d5b5e90]
Given an MCP client is configured with only the MCP endpoint URL "http://localhost:4007/mcp"
When it issues GET /.well-known/oauth-protected-resource on the same host
Then MMS returns HTTP 200 with application/json body containing:
  - resource = "http://localhost:4007/mcp"
  - authorization_servers = ["http://localhost:4007"]
  - scopes_supported including "read" and "write"
  - bearer_methods_supported = ["header"]
And the client uses authorization_servers[0] to fetch /.well-known/oauth-authorization-server next

#### failure: Document missing authorization_servers fails RFC 9728 validation [3810986e]
Given a regression ships /.well-known/oauth-protected-resource with no authorization_servers field
When an MCP client validates the document per RFC 9728
Then discovery fails — the client has no auth server URL to bootstrap from
And the QA test asserting all required RFC 9728 fields catches the regression before merge
