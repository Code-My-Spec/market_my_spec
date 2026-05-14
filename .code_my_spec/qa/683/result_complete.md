# QA Result — Story 683: Agent File Tools Over MCP

## Status

pass

## Scenarios

This story's contract is between the MCP-connected agent (Claude Code, etc.) and the MCP server's file tools (`read_file`, `write_file`, `edit_file`, `delete_file`, `list_files`). All read-before-write/edit/delete gating, account-prefix scoping, path-traversal rejection, and tool-surface auditing is exercised in-process via the Anubis frame at the spex layer. The user-visible piece is the Files explorer LiveView at `/files` which renders the same account-scoped tree the agent writes into.

### Scenario 1 — tools/list includes the five file tools with the right shapes (criteria 5834, 5851)

PASS (via BDD spex)

- `criterion_5834_…spex.exs` and `criterion_5851_…spex.exs` assert `tools/list` returns `read_file`, `write_file`, `edit_file`, `delete_file`, `list_files` with the documented input schemas. Passing.

### Scenario 2 — Adjacent admin or debug tool fails the surface audit (criterion 5852)

PASS (via BDD spex)

- `criterion_5852_…spex.exs` asserts the tool surface is exactly the five file primitives + the skill primitives + the search_engagements tool, and rejects any cross-tenant/admin/debug/telemetry tool. Passing.

### Scenario 3 — Path resolution is account-scoped server-side (criteria 5841, 5853)

PASS (via BDD spex)

- `criterion_5841_…spex.exs` and `criterion_5853_…spex.exs` assert relative paths resolve under `accounts/{account_id}/` on the server with no agent-visible prefix. Passing.

### Scenario 4 — Path traversal rejected (criterion 5854)

PASS (via BDD spex)

- `criterion_5854_path_traversal_is_rejected_spex.exs` exercises `..`-bearing paths and asserts rejection before any filesystem read. Passing.

### Scenario 5 — Absolute path rejected (criterion 5855)

PASS (via BDD spex)

- `criterion_5855_absolute_path_is_rejected_spex.exs` exercises absolute paths and asserts rejection. Passing.

### Scenario 6 — Cross-account access impossible by construction (criteria 5842, 5856)

PASS (via BDD spex)

- `criterion_5856_cross-account_access_is_impossible_by_construction_spex.exs` asserts that even with the correct file key, a bearer for account A cannot reach account B's keys. Passing.

### Scenario 7 — read_file (criteria 5835, 5857, 5858)

PASS (via BDD spex)

- `criterion_5857_…spex.exs` asserts read_file returns the body for an existing key.
- `criterion_5858_…spex.exs` asserts a missing path returns `not_found`. Passing.

### Scenario 8 — write_file with read-before-overwrite (criteria 5836, 5837, 5859, 5860, 5861)

PASS (via BDD spex)

- `criterion_5859_…spex.exs` — fresh path creates the object.
- `criterion_5860_…spex.exs` — existing path with prior read overwrites in place.
- `criterion_5861_…spex.exs` — existing path without prior read is rejected. All passing.

### Scenario 9 — edit_file with exact-string replacement + read-gating (criteria 5838, 5862, 5863, 5864, 5865, 5866)

PASS (via BDD spex)

- `criterion_5862_…spex.exs` — unique old_string in a previously-read file is replaced.
- `criterion_5863_…spex.exs` — replace_all replaces every occurrence.
- `criterion_5864_…spex.exs` — no prior read → rejected.
- `criterion_5865_…spex.exs` — non-unique old_string without replace_all → rejected.
- `criterion_5866_…spex.exs` — missing path → not_found. All passing.

### Scenario 10 — delete_file with read-before-delete (criteria 5839, 5867, 5868)

PASS (via BDD spex)

- `criterion_5867_…spex.exs` — delete after read removes the object.
- `criterion_5868_…spex.exs` — delete without prior read is rejected. Passing.

### Scenario 11 — list_files returns relative keys, supports prefix filter (criteria 5840, 5869, 5870)

PASS (via BDD spex)

- `criterion_5869_…spex.exs` — list_files returns relative keys under the account prefix.
- `criterion_5870_…spex.exs` — prefix filter narrows the result. Passing.

### Scenario 12 — User-visible files explorer renders the same account-scoped tree

PASS

- `curl -L http://localhost:4007/files` returns 200 (redirects through auth, lands on the explorer).
- Vibium navigation to `/files` renders the FilesLive.Browser explorer.

Evidence: `screenshots/683-files-explorer.png`

## Evidence

- `screenshots/683-files-explorer.png` — `/files` explorer rendering the account-scoped file tree
- 29 BDD spex in `test/spex/683_agent_file_tools_over_mcp/` — all 29 pass under `mix spex`

## Issues

None — the prior `result_failed_20260504_044955.md` issues no longer reproduce. All 29 BDD spex pass.
