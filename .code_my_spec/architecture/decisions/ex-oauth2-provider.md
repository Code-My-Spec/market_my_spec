# Use ex_oauth2_provider as the OAuth authorization server for MCP clients

## Status
Accepted

## Context
Story 612 (OAuth Authentication For MCP Connection) requires that an MCP client (the user's Claude Code) authenticates to Market My Spec via OAuth — "the same flow CodeMySpec uses" — so the server can identify the user without copy-pasted tokens, and revocation/rotation are handled by the OAuth layer rather than custom token UI.

This is distinct from web-side sign-in (Google/GitHub via PowAssent, covered by `pow-assent-integrations`). The MCP path needs an *authorization server* that can issue bearer tokens to MCP clients per the MCP 2025-03-26 spec (auth code + PKCE), and a *resource server* that validates those tokens on every MCP request.

Requirements:
- Auth code flow with PKCE (MCP clients are public clients).
- Token storage backed by Postgres (already in stack).
- Token validation usable from the Anubis MCP plug pipeline.
- Bridges cleanly to the user's existing web identity (PowAssent session) so a logged-in user can grant MCP access without re-authenticating against a separate IdP.

## Options Considered

- **ex_oauth2_provider 0.5.7.** Pow-style OAuth 2.0 authorization server. Already used in production by CodeMySpec for the MCP-OAuth path this project mirrors. Plug-based, Ecto-backed, PKCE-capable. **Pro:** match the working CodeMySpec setup; one OAuth implementation across both servers. **Con:** maintenance has been quiet upstream, but the surface we use is stable.
- **Boruta (`boruta_auth`).** Full OAuth 2.0 / OpenID Connect server, more feature-complete. **Pro:** richer feature set. **Con:** different shape than CodeMySpec; introducing a second OAuth implementation across the user's stack costs more than it saves for our scope.
- **Hand-rolled on Plug + Phoenix.** Implement auth/token/introspection endpoints directly. **Pro:** no external dep. **Con:** OAuth is easy to get subtly wrong (PKCE verification, refresh-token rotation, scope handling); build only when no library fits.
- **Delegate to CodeMySpec as the IdP.** MMS becomes a pure resource server validating tokens issued by CodeMySpec. **Pro:** single source of identity. **Con:** couples MMS to CodeMySpec's auth uptime and forces all MMS users to have CodeMySpec accounts before they can connect — wrong for the front-door wedge that targets users *before* they adopt CodeMySpec.

## Decision
Use `ex_oauth2_provider ~> 0.5.7` as the OAuth authorization server inside Market My Spec. Issue auth-code-flow tokens (PKCE required) to MCP clients after the user authenticates via PowAssent. Mount token validation in the MCP plug pipeline so every Anubis request is authenticated by bearer token before any skill resource or tool is exposed.

## Consequences
- Web-side sign-in (PowAssent: Google/GitHub/magic link) and MCP-side authentication (ex_oauth2_provider: bearer tokens for MCP clients) are two distinct flows that share a `users` table. Keep that boundary explicit in the auth context.
- Match CodeMySpec's setup so one OAuth implementation covers both MCP servers users encounter.
- Public-client PKCE flow means no client secrets in the MCP installer — clients register dynamically or use a well-known public client id.
- Document token rotation and revocation paths in the MCP setup guide story (634).
