# MarketMySpecWeb.McpController

MCP server endpoint mounting Anubis MCP. Validates the bearer token (issued by McpAuth), then handles JSON-RPC requests over POST and the long-lived SSE stream. Exposes the marketing-strategy skill's orientation/steps as MCP resources and an artifact-tracking tool the agent calls when each step is completed.

## Type

controller

## Dependencies

- MarketMySpec.Skills
- MarketMySpec.McpAuth
