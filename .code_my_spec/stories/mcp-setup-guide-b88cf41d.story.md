# MCP Setup Guide

As a new user, I want a step-by-step setup guide for installing the Market My Spec MCP in Claude Code (install command, OAuth sign-in, first interview), so I can go from sign-up to interview start without trial and error.

## Meta
- id: b88cf41d-1619-44a8-87ba-e6020228dde1
- number: 634
- status: in_progress
- priority: 1
- component: MarketMySpec.McpAuth.ConnectionInfo
- personas: founder

## Rules

### The MCP setup guide on /mcp-setup walks the user through three explicit numbered phases — (1) install plugin in Claude Code, (2) complete OAuth sign-in on first /marketing-strategy invocation, (3) walk through the first marketing-strategy interview — each with the exact command to run and the expected result to verify ("you should see X").

#### happy: New user follows guide top-to-bottom and ships first interview [f1deb19f]
Given a freshly signed-in user navigates to /mcp-setup
When they read phase 1 ("Install the plugin"), copy the install command, paste into terminal, and run it
Then they see the expected result described on the page (plugin registered in Claude Code config)
When they read phase 2 ("Sign in via OAuth") and run /marketing-strategy in Claude Code
Then their browser opens to /oauth/authorize, they approve, and the plugin reports "connected" in the terminal
When they read phase 3 ("Start your first interview") and continue interacting with the agent
Then the orientation prompt loads and step 1 begins
And the user has produced their first marketing/positioning.md artifact within the session

#### failure: Page lacking expected-result verification step is rejected [06af660b]
Given a draft of /mcp-setup ships with phase commands but no "expected result" line under any phase
When QA loads the page and audits each phase against the rule
Then the draft is rejected — without verification breadcrumbs, users have no way to know if a step worked before moving on
And the draft is reverted to include "you should see X" callouts for each phase

### The guide includes troubleshooting blocks for the three highest-probability failure modes: port conflict on first /marketing-strategy invocation, OAuth callback redirect mismatch (wrong host configured in OAuth app), and Claude Code missing/wrong claude_code version — each with diagnostic step + remediation.

#### happy: User hits port conflict and recovers via troubleshooting block [9f98864c]
Given a user runs /marketing-strategy and the local OAuth callback listener fails to bind because port 6444 is in use
When they scroll to the troubleshooting section of /mcp-setup
Then they see the "Port conflict on OAuth callback" block with:
  - diagnostic command (lsof -i :6444 or equivalent)
  - remediation (set CLAUDE_OAUTH_PORT env var to a free port and re-run)
When they apply the remediation and re-run /marketing-strategy
Then OAuth completes successfully and the plugin connects

#### failure: Page missing one of the three required troubleshooting blocks is rejected [9b0102b1]
Given a draft of /mcp-setup omits the "OAuth callback redirect mismatch" troubleshooting block
When QA audits the page against the rule's three required failure-mode blocks
Then the draft is rejected
And the missing troubleshooting block is added before merge
