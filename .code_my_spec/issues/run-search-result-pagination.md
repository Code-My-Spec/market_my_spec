# `run_search` returns full snippet payload uncapped; large saved searches blow MCP token limit

Filed 2026-05-24 from MMS MCP usage during the CodeMySpec marketing cycle. **Priority: high** — actively blocking lead-scan throughput.

## Problem

`run_search` returns the full candidate list with snippets in a single MCP response. For saved searches that match many threads, the payload exceeds the MCP token limit and gets auto-saved to disk by the runtime, forcing the agent to grep into the saved JSON file with `jq` to extract thread IDs.

Today's reproduction (2026-05-24 session, all three searches run in parallel):

| Saved search | Result size | Outcome |
|---|---|---|
| 6 (harness conversation) | 57,675 chars | Auto-saved to disk |
| 8 (agent durability) | 98,363 chars | Auto-saved to disk |
| 3 (ChatGPTCoding + ClaudeAI) | inline (within budget) | Usable |

When the runtime saves to disk, the agent has to:

1. Read disk path from the error message
2. Slice the JSON via `jq` or python (Read tool's offset/limit doesn't chunk single-line JSON well)
3. Manually extract `source_thread_id`, `thread_id`, `score`, `reply_count` per candidate
4. Filter to fresh / unengaged ones in shell

That's a 30-60 second detour per blown search, repeated across every lead-scan session.

## Why it matters

1. **Lead-scan throughput degrades.** The whole point of the saved-search orchestration is "agent runs N searches, picks top candidates, stages touchpoints." When the agent has to drop into shell to read results, the orchestration value evaporates.
2. **Snippets are useful for triage but expensive in token budget.** A 200-char snippet × 50 candidates × N searches blows the budget. The agent only needs full snippets for the 2-3 candidates it's actually staging.
3. **Disk-spill is a fallback, not a UX.** The runtime spilling to disk works as a safety net but isn't a workflow. The agent should never need to touch shell to consume a saved-search result.

## Proposed design (per operator request)

Persist the search results temporarily and make them queryable by page:

1. **`run_search` persists a `SearchRun` row** with: `search_id`, `ran_at`, `candidates` (JSON blob), `ttl_at` (e.g. ran_at + 1 hour).
2. **`run_search` response returns** a `search_run_id` + first page (default 10 candidates) + pagination metadata (`total_count`, `page: 1`, `page_size: 10`, `has_more: true|false`).
3. **New tool `get_search_page(search_run_id, page, page_size)`** fetches subsequent pages from the persisted row. Stable ordering across pages (sort key locked at run time).
4. **TTL'd cleanup** removes search runs older than N hours so the table doesn't accumulate.

## Acceptance criteria

1. `SearchRun` schema + migration shipped, with TTL column and an Oban/scheduled cleanup task.
2. `run_search` returns `{search_run_id, page: 1, page_size, total_count, has_more, candidates: [...]}` — first page only.
3. `get_search_page` MCP tool registered; accepts `search_run_id`, `page` (1-indexed), `page_size` (default 10, max 50). Returns the same envelope shape as `run_search`.
4. Page size enforced so a single page can never exceed a safe token budget (suggest cap at ~15k chars to leave headroom under MCP limits).
5. `run_search` docstring updated to document the pagination behavior and the `get_search_page` tool.

## Out of scope

- Snippet truncation as the primary fix. Snippets are valuable for triage; pagination preserves them while keeping responses bounded.
- A `summary_mode` flag that strips snippets entirely. Could be added later as an optimization but pagination solves the immediate problem.
- Search-result caching beyond the TTL. If the operator wants fresh results, they re-run the search.

## History

- 2026-05-24 morning: blew MCP token limit on saved searches 6 and 8 during a single parallel `run_search` call. Worked around by `jq` over the spilled JSON files. Lost ~2 minutes of session time and several hundred tokens of context to read the spilled files.

## Reference

- Caller-side: today's session in `code_my_spec_marketing` (touchpoints staged on threads 1tlcai2, 1tll4mv, 1tlgzmn, 1tk2m2x).
- Related: `search-recency-uses-mms-indexed-not-source-created.md` (the freshness-filter request — together pagination + freshness would drop result sizes by ~3x for typical lead-scan use).
