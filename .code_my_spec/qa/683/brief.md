# QA Brief: Story 683 — Agent File Tools Over MCP

## Tool

curl (for unauthenticated MCP endpoint probe) + static code audit (no browser needed — this is an MCP/API story with no UI flows to test at this scope)

## Auth

MCP endpoint is bearer-token authenticated via the `:mcp_authenticated` pipeline (`MarketMySpecWeb.Plugs.RequireMcpToken`). Minting a bearer token requires a full OAuth exchange which is out of scope for this QA session (sub-agent permissions block it). The endpoint probe is limited to the unauthenticated surface:

```
curl -i -X POST http://localhost:4008/mcp
```

Expected: 401 with `WWW-Authenticate: Bearer ...` header and `{"error":"unauthorized"}` body.

## Seeds

No seeds required for the static audit. The spex files use `Fixtures.account_scoped_user_fixture()` directly via `mix test`, which is the correct approach for session-gated unit-level spex. If running the spex is needed later: `mix test test/spex/683_agent_file_tools_over_mcp/`.

## What To Test

### 1. MCP Endpoint Probe (unauthenticated)

- POST `http://localhost:4008/mcp` with no token
- Expect: 401 status, `WWW-Authenticate` header present, `{"error":"unauthorized"}` body

### 2. Static Audit: Tool Modules Present vs. Required

The story requires five tools: `read_file`, `write_file`, `edit_file`, `delete_file`, `list_files`.

Check `lib/market_my_spec/mcp_servers/marketing/tools/` for all five modules:
- `read_file.ex` — ReadFile
- `write_file.ex` — WriteFile
- `list_files.ex` — ListFiles
- `edit_file.ex` — EditFile (EXPECTED MISSING per 676 QA report)
- `delete_file.ex` — DeleteFile (EXPECTED MISSING per 676 QA report)

### 3. Static Audit: Tool Registration in MarketingStrategyServer

Read `lib/market_my_spec/mcp_servers/marketing_strategy_server.ex`. Confirm which tool modules are registered as `component(...)`. Note any of the five file tools that are absent.

### 4. Static Audit: Files Context API Coverage

Read `lib/market_my_spec/files.ex`. Confirm presence/absence of:
- `put/3` or `put/4` — used by WriteFile
- `get/2` — used by ReadFile
- `list/2` — used by ListFiles
- `delete/2` — used by DeleteFile (if module exists)
- `edit/3` or equivalent — used by EditFile (if module exists)

Note: the acceptance criteria require read-before-write gating, read-before-edit gating, and read-before-delete gating. Check whether WriteFile enforces read-before-overwrite gating in session state.

### 5. Static Audit: Spex Quality Assessment

Read representative spex files from `test/spex/683_agent_file_tools_over_mcp/`. Confirm whether they are:
- Substantive: use Frame.execute pattern calling tool modules directly with real assertions
- Anemic: only check file existence or module compilation

Note: spex referencing `MarketMySpec.McpServers.Marketing.tools()` require a `Marketing` module with a `tools/0` function — check if this exists.

### 6. Static Audit: Path Traversal and Absolute Path Rejection

Review `lib/market_my_spec/files.ex` `validate_path/1` function. Confirm it rejects:
- Paths starting with `/` (absolute paths)
- Paths containing `..` (traversal attempts)

### 7. Static Audit: Cross-Tenant Scoping

Review `resolve/2` in `lib/market_my_spec/files.ex`. Confirm account prefix is applied server-side and relative paths returned by `list/2` strip the account prefix.

## Result Path

`.code_my_spec/qa/683/result.md`

## Setup Notes

The server is running on port 4008 (not the 4007 default documented in the QA plan — port was updated for recent stories). The QA plan should be updated to reflect the active port.

The spex files reference `MarketMySpec.McpServers.Marketing` (a module, not `MarketingStrategyServer`) with a `tools/0` function. This module does not exist in the codebase. This is a prerequisite for the spex to compile and run.
