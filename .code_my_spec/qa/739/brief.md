# QA Brief — Story 739: Run a problem-discovery pipeline whose board is killable in one click

## Tool

web (Vibium browser for LiveView surfaces) + curl (MCP API at /problem-discovery)

## Auth

### Browser (LiveView surfaces)

1. Run `mix run priv/repo/qa_seeds.exs` to get a fresh magic-link token for `qa@marketmyspec.test`.
2. Navigate to `http://localhost:4007/users/log-in`.
3. Fill `input[name='user[email]']` with `qa@marketmyspec.test`.
4. Click the magic-link submit button.
5. Alternatively, use password login:
   - Scroll to `#login_form_password`
   - Fill `#login_form_password_email` with `qa@marketmyspec.test`
   - Fill `#user_password` with `hello world!`
   - Click `#login_form_password button[name='user[remember_me]']`
   - Wait for redirect to `/accounts`

### MCP API (curl)

1. Run `mix run priv/repo/qa_seeds_743.exs` to mint a fresh bearer token.
2. Copy the printed bearer token from stdout.
3. Use `Authorization: Bearer <token>` header in all curl calls to `http://localhost:4007/mcp/problem-discovery`.

The MCP endpoint uses streamable HTTP (JSON-RPC over POST). Each request must include `Content-Type: application/json`.

## Seeds

Run both seed scripts in order:

```
cd /Users/johndavenport/Documents/github/market_my_spec
mix run priv/repo/qa_seeds.exs
mix run priv/repo/qa_seeds_743.exs
```

The second script prints the bearer token needed for MCP curl calls.

## What To Test

### Scenario 1: Create a Frame via MCP API

- Initialize the MCP session:
  ```
  curl -sS -X POST http://localhost:4007/mcp/problem-discovery \
    -H "Authorization: Bearer <TOKEN>" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"qa","version":"1.0"}}}'
  ```
- Call `create_frame` tool with a hypothesis description, saved searches (source: "upwork"), money_gate, and kill_condition parameters.
- Verify the response returns a `frame_id`.
- Expected: `{"frame_id": "<uuid>"}` in the response content.

### Scenario 2: Run the full pipeline (Gather → Cluster → Score)

- Call `run_gather` tool with the `frame_id`.
- Verify gather returns job postings (per_saved_search list with gathered counts > 0).
- Call `run_cluster` tool with the `frame_id`.
- Verify cluster returns candidates (single KMeans pass, not multi-pass).
- Call `run_score` tool with the `frame_id`.
- Verify score returns scored candidates.
- Expected: Pipeline runs all three stages and each returns a success response.

### Scenario 3: Red-team candidates with all four canonical verdicts

- Call `list_candidates` tool with the `frame_id`.
- For the survivors (score > 0), assign verdicts cycling through: `keep_productizable`, `keep_service_only`, `watch`, `kill`.
- Call `red_team_candidate` tool for each candidate with the appropriate verdict, kill_argument, and cheapest_kill_test.
- Expected: Each red-team call returns `{:ok, ...}` and persists the verdict.

### Scenario 4: View the Board via GetBoard MCP tool

- Call `get_board` tool with the `frame_id`.
- Verify the response includes a `candidates` list.
- Verify every candidate row has a `verdict` field from the canonical four.
- Verify surviving candidates have `verification_links` with at least one `http(s)://` URL.
- Expected: Board returns typed structs with verdicts + verification links.

### Scenario 5: View the Frame detail LiveView — Board renders all four verdicts

- Log in via browser as `qa@marketmyspec.test`.
- Navigate to `http://localhost:4007/problem-discovery/frames`.
- Click through to the Frame created in Scenario 1.
- Expected: Page loads at `/problem-discovery/frames/:id`.
- Verify the Board section shows rows with `data-test="board-row"` elements.
- Verify rows with `data-verdict="keep_productizable"`, `data-verdict="keep_service_only"`, `data-verdict="watch"`, and `data-verdict="kill"` all render.
- Capture screenshot showing all four verdict types.

### Scenario 6: Kill a candidate in one click from the Board

- On the Frame detail LiveView, locate a candidate row that is NOT already `kill`.
- Click the `data-test="kill-button"` on that row.
- Expected: The page reloads the board and the killed candidate's verdict changes to `kill`.
- Verify no page reload — LiveView updates inline.
- Capture screenshot of the kill action result.

### Scenario 7: Verify verification links are openable

- On the Board, inspect candidate rows for verification link text.
- Verify that displayed links start with `http://` or `https://`.
- If the Board renders links as clickable anchors, verify they open (check href attribute).
- Expected: At least one openable URL per surviving candidate.

### Scenario 8: Empty Gather halts pipeline and shows notice

- Create a second Frame via MCP with saved searches designed to return zero results (use a nonsense query like "definitively_unmatched_query_xyzzy_42").
- Call `run_gather` on that frame.
- Verify the gather response shows 0 postings in `per_saved_search`.
- Attempt `run_cluster` on the empty-gather frame.
- Verify cluster returns a halt/empty status (not a stack trace).
- Navigate to the Frame detail LiveView for that frame.
- Verify `data-test="empty-gather-notice"` is visible on the page.
- Capture screenshot of the empty-gather notice.

### Scenario 9: Skill orientation contains all six phases and tool names

- Via MCP, read the `skill-orientation` resource from the problem-discovery server.
- Or check via curl that the resource returns the SKILL.md content.
- Verify the response body mentions: Frame, Gather, Cluster, Score, Red-team, Board (all six phases).
- Verify the response body mentions all required tools: CreateFrame, RunGather, RunCluster, RunScore, RedTeamCandidate, GetBoard, SetPainDescriptor, MergeCandidates, SplitCandidate, LabelCandidate.
- Verify it mentions founder-direct LiveView surfaces and skill-driven agent flows.
- Expected: SKILL.md orientation document is complete per criterion 6579.

### Scenario 10: Probe-mode Gather does not persist a Frame

- Call `run_gather` with `mode: "probe"` and a draft frame definition (no frame_id, just inline frame attrs).
- Verify the response includes a `sample` list of job postings.
- Call `list_frames` to confirm no Frame was persisted.
- Verify the probe response does NOT carry a `frame_id`.
- Expected: Probe returns samples without creating any DB records.

## Setup Notes

The problem-discovery MCP server is at `/mcp/problem-discovery` (distinct from `/mcp/` and `/mcp/analytics-admin`). Auth uses the same `RequireMcpToken` plug pattern — the bearer token from `qa_seeds_743.exs` is tied to `qa@marketmyspec.test`'s account scope, so all MCP tool calls operate in that user's context.

The MCP endpoint uses Anubis streamable HTTP transport. Initialize the session first, then call tools via `tools/call` method.

The APIFY_API_TOKEN must be configured in the dev environment for Gather to actually fetch from Upwork via the Apify actor. The story prompt confirms this is set.

## Result Path

`.code_my_spec/qa/739/result.md`
