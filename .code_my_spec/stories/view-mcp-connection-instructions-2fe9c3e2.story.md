# View MCP Connection Instructions

As an authenticated user, I want clear instructions for connecting Market My Spec as an MCP server in Claude Code (server URL, OAuth flow), so I can complete setup without guessing.

## Meta
- id: 2fe9c3e2-375d-4274-b912-91eed079dbd0
- number: 611
- status: in_progress
- priority: 1
- component: MarketMySpec.McpAuth.ConnectionInfo
- personas: founder

## Rules

### Authenticated users at /mcp-setup see one self-contained page with: the canonical MCP server URL for the current environment (host + port), a copyable plugin install command in monospace, and a numbered walkthrough of the OAuth sign-in flow — without having to navigate elsewhere or read docs to complete setup.

#### happy: Signed-in user lands on /mcp-setup with everything they need [e1ada431]
Given a signed-in user navigates to /mcp-setup
When the page renders
Then they see the MCP server URL for this environment (e.g., http://localhost:4007/mcp in dev) rendered in monospace
And a copyable plugin install command in monospace with a copy affordance
And a numbered list explaining the OAuth flow they will see when running the plugin (1. Claude Code opens browser, 2. user signs into MMS, 3. consent, 4. Claude Code receives bearer)
And no further navigation is required to complete setup

#### failure: Page missing server URL or install command is rejected [d89157b4]
Given a regression ships /mcp-setup with the server URL missing OR the install command absent
When QA loads the page
Then the page fails the "everything in one place" bar
And QA tests for the presence of MCP server URL, install command, and OAuth walkthrough on /mcp-setup catch the regression before merge

### Anonymous visitors hitting /mcp-setup are redirected to /users/log-in with a return_to parameter so that after sign-in they land back on /mcp-setup — connection instructions are not exposed without auth.

#### happy: Anonymous visitor is bounced through sign-in to /mcp-setup [6884b173]
Given an anonymous visitor navigates to /mcp-setup
When the request reaches the :require_authenticated_user pipeline
Then they are redirected to /users/log-in with return_to=/mcp-setup (or equivalent path-preservation mechanism)
When they complete magic-link or OAuth sign-in
Then they land on /mcp-setup with the page rendered

#### failure: Anonymous request gets no connection details in the response body [c9588047]
Given an anonymous client issues GET /mcp-setup
When the request is processed
Then the response is a redirect to /users/log-in
And the redirect response body contains no MCP server URL, no install command, and no OAuth walkthrough copy
And no part of the page leaks via flash, session, or rendered HTML before the redirect
