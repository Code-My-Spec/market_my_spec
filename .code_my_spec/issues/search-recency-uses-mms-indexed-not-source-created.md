# `search_engagements` / `run_search` `recency` field reflects MMS indexing time, not source thread creation time

Filed 2026-05-22 from MMS MCP usage during the CodeMySpec marketing cycle. **Reoccurred 2026-05-24** — operator confirms this is now a high-priority blocker for lead-scan throughput, paired with the search-pagination issue.

## Problem

The `recency` field in search-result candidates returned by `search_engagements` and `run_search` is set to when MMS last indexed/saw the thread, NOT when the thread was created on the source platform.

Effect today: ranking results "by recency" surfaced months-old threads as if they were current. The operator picked 3 "top" candidates that turned out to be 6-7 months old (Reddit IDs `1o6j1yr`, `1otf3xc`, `1pzu2bx` — `1o*` and `1p*` prefixes correspond to ~Sept-Nov 2025; current threads use `1t*` prefix). All three had `recency: "2026-05-22T13:44:..."` because MMS re-indexed them today.

Engagement on 6-month-old Reddit threads is functionally dead — the OP has moved on, the audience has cycled, and a fresh comment lands cold. The operator catches the mistake only on manual ID inspection.

## Why it matters

1. **Operator decisions get distorted.** "High score + recent activity" is a normal ranking heuristic; the current `recency` field makes it return false positives.
2. **Lead-scan throughput degrades.** Operators waste time evaluating candidates that look fresh but aren't, then have to manually filter — defeats the purpose of the orchestration layer.
3. **Adoption signal for engagement is wrong.** A high-score old thread is not equivalent to a high-score new thread; conflating them muddles the prioritization.

## Acceptance criteria

1. **Add a `source_created_at` field** to the candidate envelope returned by `search_engagements` and `run_search`. Source it from:
   - Reddit: the `created_utc` field on the post (already in the Reddit API response)
   - ElixirForum: the `created_at` field on the topic
2. **Keep the existing `recency` field** for backward compatibility but rename it in docs to `last_indexed_at` to remove ambiguity. Mark the old name as deprecated in the docstring.
3. **Add an optional `max_age_days` parameter** to `search_engagements` and `run_search` — when set, the orchestrator filters out candidates whose `source_created_at` is older than that. Default unset (no filter). Reasonable operator default for lead-scans: 14 days.
4. **Document recommended use** in the tool docstring: "For lead-scan workflows, set `max_age_days: 14` to surface only current threads. Older threads are kept in the index for engagement-history lookup but rarely produce new conversation."

## Out of scope

- Re-fetching `created_utc` for already-indexed threads from prior scans. New scans populate the new field; old records can backfill on next re-index.
- Per-source thread-archival rules. The index keeps everything; the filter just changes default visibility.

## Reference

- Caller-side discovery: 2026-05-22 lead-scan run misranked 3 candidates as "top" before manual ID-prefix inspection caught they were Sept-Oct 2025 threads. Operator surfaced this in conversation: "chatgptcoding is dead. We might need to improve our recency story in mms."
- 2026-05-24 reoccurrence: same workflow tax across saved searches 3, 6, and 8. Agent worked around by filtering on Reddit ID prefix (`1tk*` / `1tl*` only) before staging. Operator confirmed in feedback session: high-priority alongside `run-search-result-pagination.md`.
- Daily file: `code_my_spec_marketing/marketing/daily/2026-05-22.md` (referenced as MMS gap #8).
- Related: `run-search-result-pagination.md` (the result-payload-too-large request — pagination + freshness work in concert to cut response size).
