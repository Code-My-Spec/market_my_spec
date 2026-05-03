# MarketMySpec.McpAuth

OAuth 2.0 authorization server for MCP clients. Wraps ex_oauth2_provider so the user's Claude Code (or other MCP client) can authenticate via auth-code + PKCE and receive a bearer token used to call the MCP endpoint. Distinct from web-side sign-in.

## Type

context

## Dependencies

- MarketMySpec.Users
