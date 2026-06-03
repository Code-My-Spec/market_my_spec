# QA Brief: Story 741 — Red-team every surviving candidate from the same evidence

## Tool

curl (MCP bearer token against `/mcp/problem-discovery` API endpoint)

## Auth

Run the seed script to get a fresh bearer token:

```
mix run priv/repo/qa_seeds_743.exs
```

Copy the `Bearer token:` value printed to stdout. All curl commands use:

```
-H "Authorization: Bearer <token>"
-H "Content-Type: application/json"
```

MCP endpoint: `http://localhost:4007/mcp/problem-discovery`

All MCP calls use `tools/call` method. Full example:

```
curl -sS -X POST http://localhost:4007/mcp/problem-discovery \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"qa","version":"1.0"}}}'
```

After initialize, use session ID from response for subsequent calls.

## Seeds

```
mix run priv/repo/qa_seeds.exs
mix run priv/repo/qa_seeds_743.exs
```

The second script prints the bearer token and confirms the QA user. No story-specific seed data is needed beyond the bearer token — the test creates its own Frames via MCP tool calls.

## What To Test

All tests drive the MCP surface via curl. The full pipeline for each scenario is:
`CreateFrame → RunGather → RunCluster → RunScore → ListCandidates → [RedTeamCandidate] → GetBoard`

### Scenario 1: Board excludes survivors without a RedTeamVerdict (criterion 6546 + 6553)

1. Initialize MCP session
2. Call `create_frame` with description="QA 741 Red-team board exclusion" and a saved search for "vendor onboarding" on Upwork
3. Call `run_gather`, `run_cluster`, `run_score` in sequence
4. Call `list_candidates` — filter to survivors (`score >= 1`)
5. Call `get_board` WITHOUT calling `red_team_candidate` first
6. Expected: `candidates` array in board response is empty (`[]`)
7. Expected: board response contains `awaiting_redteam` field (integer count or list) equal to the number of survivors
8. Screenshot/save response body as evidence

### Scenario 2: Red-team all survivors with `keep_productizable`, Board renders them (criterion 6546)

1. Using the same frame from Scenario 1 (or create a new one)
2. For each survivor from `list_candidates`: call `red_team_candidate` with `verdict: "keep_productizable"`, a kill argument, and a cheapest kill test
3. Call `get_board`
4. Expected: `candidates` array now contains one row per survivor
5. Expected: each row has `verdict`, `kill_argument`, and `cheapest_kill_test` fields (criterion 6550)

### Scenario 3: All 4 verdict types accepted (criterion 6548 + 6549)

Create a fresh frame, run the full pipeline, get survivors. Red-team each survivor with a different verdict:
- First survivor: `keep_productizable`
- Second survivor (if exists): `keep_service_only`
- Third survivor (if exists): `watch`
- Fourth survivor (if exists): `kill`

If fewer than 4 survivors, re-use verdict permutations on a second run on the same candidate (overwrite semantics).

Expected: each `red_team_candidate` call succeeds with `{"candidate_id": "...", "verdict": "..."}` in the response.

Expected: each call returns exactly one `kill_argument` string and one `cheapest_kill_test` string in the stored verdict (verifiable via `get_board`).

### Scenario 4: Board row exposes prosecution residue (criterion 6550)

1. After red-teaming survivors, call `get_board`
2. For each Board row: verify it contains `kill_argument` (non-empty string) and `cheapest_kill_test` (non-empty string) alongside `verdict`
3. Save board response as evidence

### Scenario 5: Red-team flip from KEEP to KILL overwrites Score's verdict (criterion 6555)

1. Create a new frame, run full pipeline, get survivors
2. Red-team the first survivor with `verdict: "kill"`, plus a kill argument and cheapest kill test
3. Call `get_board`
4. Expected: Board row for that candidate shows `verdict: "kill"` (not Score's mechanical classification)

### Scenario 6: Candidate without RedTeamVerdict shows as `awaiting_redteam` diagnostic (criterion 6553)

1. Create a frame, run pipeline to completion
2. Red-team only the first N-1 survivors (leave the last one un-prosecuted)
3. Call `get_board`
4. Expected: `awaiting_redteam` field is present and equals 1
5. Expected: un-prosecuted candidate does NOT appear in `candidates` array

### Scenario 7: Red-team scope isolation — prosecution context uses only candidate's own evidence (criterion 6547)

1. After red-teaming in prior scenarios: call `get_board` on one frame
2. Verify board rows: each row's `kill_argument` and `cheapest_kill_test` are the exact strings passed to `red_team_candidate` for THAT candidate's ID, not a different candidate's strings
3. This verifies no cross-candidate contamination

### Scenario 8: RedTeamVerdict candidate association is one-to-one (criterion 6552)

1. Red-team a candidate twice (call `red_team_candidate` for the same `candidate_id` with a different verdict)
2. Call `get_board`
3. Expected: only one row for that candidate (the second call overwrites the first)
4. Expected: verdict on Board matches the second call's verdict

### Scenario 9: Red-team is called once per candidate, never in batch (criterion 6554)

1. Confirm the `red_team_candidate` tool schema accepts only a single `candidate_id` field (no array/batch param)
2. Attempt to pass an array as `candidate_id` — expected: error response
3. Verify each call in prior scenarios targeted exactly one candidate

### Scenario 10: Skill orientation directs past-tense pre-mortem grammar (criterion 6551)

1. Fetch the `problem-discovery://skill` resource via MCP `resources/read`
2. Verify the skill orientation text mentions past-tense pre-mortem grammar
3. Save response as evidence

## Result Path

`.code_my_spec/qa/741/`

Findings filed via `create_issue` as discovered. Evidence (curl response JSON) saved to `.code_my_spec/qa/741/screenshots/`.
