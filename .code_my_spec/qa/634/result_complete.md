# QA Result — Story 634: MCP Setup Guide

## Status

pass

## Scenarios

### Scenario 1 — Page contains all three required steps (criterion 5705)

PASS

- Authenticated GET of `/mcp-setup` (verified during story 611 QA) renders three numbered steps:
  1. `[data-test="install-step"]` — "Install the MCP plugin" with the `claude mcp add market-my-spec http://localhost:4007/mcp` command in `[data-test="install-command"]`.
  2. `[data-test="oauth-step"]` — "Sign in via OAuth" with `[data-test="oauth-instructions"]` and `[data-test="server-url"]` showing `http://localhost:4007/mcp`.
  3. `[data-test="interview-step"]` — "Start your first interview" with the suggested LLM prompt.

Evidence: `screenshots/634-mcp-setup-page.png`

### Scenario 2 — Page has the expected-result verification step (criterion 5706)

PASS

- `[data-test="expected-result"]` is present on the page, containing the success-confirmation copy: "In Claude Code, `market-my-spec` appears under your connected MCP servers and the marketing-strategy skill is installed and ready to use."
- This is the success-verification block the criterion guards against missing.

### Scenario 3 — Port conflict troubleshooting block helps the user recover (criterion 5707)

PASS

- `[data-test="port-conflict-troubleshooting"]` details element is present.
- Body text instructs: "Find the offending process with `lsof -nP -iTCP:<port>`, stop it, and retry the install. Restart Claude Code if the conflict persists." — a concrete, actionable recovery path.

### Scenario 4 — All three required troubleshooting blocks are present (criterion 5708)

PASS

The Troubleshooting section contains all three required `[data-test="*-troubleshooting"]` details blocks:
- `[data-test="port-conflict-troubleshooting"]` — port-conflict recovery
- `[data-test="oauth-troubleshooting"]` — OAuth authorization failures (stale sessions, redirect URI rejections)
- `[data-test="mcp-connection-troubleshooting"]` — connection drops / never-connecting recovery (`claude mcp list`, restart Claude Code, network proxies)

## Evidence

- `screenshots/634-mcp-setup-page.png` — authenticated `/mcp-setup` rendering showing all three steps, expected-result block, and three troubleshooting blocks
- 4 BDD spex in `test/spex/634_mcp_setup_guide/` — all 4 pass under `mix spex`

## Issues

None — the prior `result_failed_20260503_221119.md` issues no longer reproduce. All 4 BDD spex pass and all four scenarios verify correct presence of the required data-test selectors.
