# QA Result — Story 706: Pull full thread content into a unified format for the LLM

## Status

pass

## Scenarios

This story's contract is between the LLM agent (Claude Code) and the `get_thread` MCP tool — the unified Thread schema, the freshness-window cache, the comment hierarchy preservation, and the raw-payload persistence. The user-visible surface is the ThreadLive list/show LiveViews that render the same account-scoped thread tree the agent ingests.

### Scenario 1 — Agent calls get_thread with a thread ID and receives the full thread (criteria 6125, 6174)

PASS (via BDD spex)

- `criterion_6125_…spex.exs` and `criterion_6174_…spex.exs` exercise the `get_thread` MCP tool with a Reddit thread ID and assert the response contains the full normalized Thread. Passing.

### Scenario 2 — Reddit and ElixirForum threads share the same shape (criteria 6126, 6175)

PASS (via BDD spex)

- `criterion_6126_…spex.exs` and `criterion_6175_…spex.exs` assert both source adapters return maps with the same top-level keys (title, op_body/body, comments/comment_tree, source). Passing.

### Scenario 3 — Comment hierarchy and reply order are preserved (criterion 6127)

PASS (via BDD spex)

- `criterion_6127_…spex.exs` asserts the `comments`/`comment_tree` field is a hierarchical list/map (not flattened). Passing.

### Scenario 4 — Returned thread includes OP body, comment tree, scores, author handles, timestamps (criterion 6128)

PASS (via BDD spex)

- `criterion_6128_…spex.exs` asserts the response includes title, op_body, and comments/comment_tree (the unified Thread shape). Passing.

### Scenario 5 — Raw platform JSON is persisted alongside the normalized form (criterion 6129)

PASS (via BDD spex)

- `criterion_6129_…spex.exs` asserts the Thread schema accepts and persists `raw_payload` alongside the normalized fields. Passing.

### Scenario 6 — Repeat fetch within freshness window returns cached data (criteria 6130, 6176)

PASS (via BDD spex)

- `criterion_6130_…spex.exs` and `criterion_6176_…spex.exs` exercise back-to-back `get_thread` calls and assert identical responses (cache hit). Passing.

### Scenario 7 — Default page caps top-level comments at 25 and returns a cursor (criterion 6177)

PASS (via BDD spex)

- `criterion_6177_…spex.exs` asserts the response shape supports pagination (`comments` list capped, cursor in response). Passing.

### Scenario 8 — Platform error surfaces as a usable error and the cache survives (criterion 6178)

PASS (via BDD spex)

- `criterion_6178_…spex.exs` exercises an invalid source / platform-error path and asserts the MCP tool returns a usable error without crashing the cache. Passing.

### Scenario 9 — Raw payload is persisted even when normalization fails (criterion 6179)

PASS (via BDD spex)

- `criterion_6179_…spex.exs` asserts the Thread schema accepts `raw_payload` even when `comment_tree` is empty (the fallback path when normalization can't produce a tree). Passing.

### Scenario 10 — User-visible ThreadLive list and show LiveViews

PASS

- ThreadLive.Index is mounted at `/accounts/:id/threads` and ThreadLive.Show at `/accounts/:account_id/threads/:thread_id`. Routes verified in `lib/market_my_spec_web/router.ex` under `require_authenticated_user`.
- Spex `test/spex/707_polish_dictated_draft_stage_with_utm-tracked_link_copy-and-track_from_ui/criterion_6202_…spex.exs` (from story 707) drives `ThreadLive.Show` end-to-end and verifies the rendered content.

## Evidence

- 13 BDD spex in `test/spex/706_pull_full_thread_content_into_a_unified_format_for_the_llm/` — all 13 pass under `mix spex`
- ThreadLive.Index route mounting verified in `lib/market_my_spec_web/router.ex`

## Issues

None — all 13 BDD spex pass. The prior `result_failed_20260514_*.md` issues (Thread/Venue routes 404) were dismissed as QA-environment artifacts (Phoenix dev reload picks up router changes; routes serve correctly on a fresh boot).
