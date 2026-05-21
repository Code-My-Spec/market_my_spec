# Pending Issues

Engineering issues identified but not yet filed in CodeMySpec (MCP was down
at the time of capture). File these via `create_issue` once the CMS MCP
server is reachable again.

Captured 2026-05-17 while triaging the Reddit + ElixirForum engagement-finder
pipe after running `/scan-reddit` end-to-end locally.

---

## 1. `run_search` response too large — overflows MCP tool window, blocks `/scan-reddit` orchestration

**Severity:** high
**Source path:** `lib/market_my_spec/mcp_servers/engagements/tools/run_search.ex`

### What we saw

When running `run_search` from the engagement-finder loop, **4 of 6 searches
returned outputs in the 50k–110k char range**, overflowing the MCP tool result
window. Affected runs had to be dumped to file and processed with `jq` to
extract anything usable.

### Impact

`/scan-reddit` (and any other orchestration that runs multiple saved searches
in a single agent turn) is unusable as automation. Each search call burns
context to the point that no follow-up tool calls fit. The agent can't chain
search → stage_response in one turn because the search alone fills the window.

### Root cause

`run_search` returns `%{candidates: candidates, failures: encode_failures(failures)}`
Jason-encoded. There's a cursor / `next_cursor` design already wired into
`search_engagements` but `run_search` does not use it — every call returns
the full batch with full per-candidate payloads.

Per-candidate fields contributing to size: `snippet` (up to 280 chars × N
candidates × 6 searches), `recency`, and possibly the raw payload from the
source adapter.

### Fix options

1. **Default a hard limit** on candidates returned per call (e.g. top 30 by
   rank/score) with `next_cursor` honored so the agent can ask for more.
2. **Strip redundant fields** from the per-candidate payload. `snippet` alone
   is likely the bulk; drop it from the summary view and only return it when
   asked.
3. **Return a compact summary by default** (id, source, title, score,
   reply_count) and a separate `get_candidate_details` tool for drill-down.

### Recommended

Option 3 (compact list + drill-down). Matches the pattern needed for
human-side triage in `ThreadLive` too — full bodies live in the `threads`
table; the agent doesn't need them in tool output.

### Expected

A single `run_search` call should fit comfortably (e.g. < 5k chars) so an
agent turn can chain multiple searches + stage responses without overflow.

---

## 2. ElixirForum `chat` and `your-libraries` categories return `unknown_category`

**Severity:** low (data fix)
**Source path:** `lib/market_my_spec/engagements/source/elixir_forum.ex`

### What we saw

Two ElixirForum category slugs that exist on the live site —
`chat` and `your-libraries` — are returning `{:error, {:unknown_category, slug}}`
from `resolve_category_id/1`.

### Where it happens

The adapter resolves category slugs to numeric Discourse ids by hitting
`/categories.json` and looking up the slug in `category_list.categories`.
Either:

- the category list response on elixirforum.com doesn't include these
  slugs at the top level (they may be subcategories under another parent), or
- the slug format the user supplied doesn't match Discourse's canonical slug
  (e.g. "your libraries" vs "your-libraries" vs `your_libraries`).

### Fix

Inspect the response shape from `https://elixirforum.com/categories.json`
for these two slugs, then either:

- handle nested categories in `resolve_category_id/1` (walk
  `subcategory_ids` / `subcategory_list`), or
- normalize the supplied slug before lookup.

Add fixture coverage in the adapter spex to cover the subcategory case.

---

## 3. ElixirForum query filtering acts like venue-browse, not query-match

**Severity:** medium
**Source path:** `lib/market_my_spec/engagements/source/elixir_forum.ex`

### What we saw

Across multiple saved searches with very different vocabularies, the
ElixirForum half of the result set returned **the same ~30 LiveView-related
threads** regardless of query. By contrast, the Reddit half correctly
filtered — e.g. "Stop letting your AI hallucinate your architecture" only
appeared under the spec/BDD search, not the coherence one.

So the issue is adapter-local: ElixirForum is browsing the category's
latest topics and not honoring the query string at all.

### Root cause hypothesis

The adapter hits `/c/<slug>/<id>/l/latest.json` (category-latest), which
returns the most recent N topics regardless of search terms. Discourse's
search endpoint is at `/search.json?q=...` (and supports `category:<slug>`
as a filter inside the query). The adapter likely never wires `query` into
the URL.

### Fix

Switch the adapter from `/c/<slug>/<id>/l/latest.json` (browse) to
`/search.json?q=<query>+category:<slug>+order:latest` (search), then
normalize the search-result shape into the same candidate format.

Discourse search results have a different envelope from category-latest
(`grouped_search_result.posts` rather than `topic_list.topics`), so the
normalize step needs a small rewrite — but the candidate fields
(`source_thread_id`, `title`, `url`, `created_at`) are all present.

### Tests

Real-fixture spex via `ReqCassette` with two distinct queries against the
same category should produce two distinct candidate sets. Today both would
return identical results.

### Priority note

Lower than #1 because phoenix-forum browse is still useful (the unfiltered
list surfaces recent topics worth scanning manually). But #3 should land
before scaling out to more ElixirForum categories.

---

## Follow-up (not an issue per se — work item)

### Rewrite `scan-reddit.md` to drive off `run_search`

Once #1 lands, the existing `scan-reddit` flow (currently a manual
slash command) should be rewritten as an orchestration that calls
`run_search` across all 5 saved searches and presents a single ranked
candidate list. Currently it's effectively impossible because of the size
issue.

---

## 4. Stop hook blocks on pre-existing credo/spex unrelated to turn changes (framework)

**Scope:** framework
**Severity:** medium
**Captured:** 2026-05-17 (MCP `create_issue` returning `-32603 Internal error` at capture time, so filed here.)

### What we saw

Stop hook reports ~25–34 credo issues and 2 spex failures and refuses to let
the turn end, even when the turn's only change is a documentation copy that
touches zero Elixir files. Reproduced this turn with a single
`cp -R ../metric_flow/.code_my_spec/dev_story .code_my_spec/dev_story`. The
reported failures are all in `lib/` and `test/spex/` files that were already
dirty in the working tree at session start (visible in the session-start
`git status`).

Sample of what blocked the turn (none touched by the `cp`):

- `lib/market_my_spec/engagements/threads_repository.ex:175` — redundant `with` clause
- `lib/market_my_spec_web/live/search_live/index.ex:403` — `Enum.map_join/3` suggestion
- `lib/market_my_spec/engagements/posting.ex:38` — cyclomatic complexity 11/9
- `test/spex/672_sign_up_and_sign_in_with_google/criterion_5679_*` — `Enumerable not implemented for Atom`
- `test/spex/672_sign_up_and_sign_in_with_google/criterion_5681_*` — same

### Impact

Every non-code turn in a dirty repo (doc copy, memory edit, planning, README
nudge) gets blocked by the entire pre-existing backlog. The model's only
escapes are (a) ignore the hook, (b) do out-of-scope lint cleanup the user
didn't ask for — both violate the project's "don't refactor beyond task
scope" rule. Compounding: the documented escape hatch (`create_issue` with
`scope: framework`) was itself returning MCP `-32603` during this turn, so
the model has no clean way to flag the friction either.

### Suggested fix directions (pick one)

1. **Diff-scope the hook** to files changed by the current turn (or
   session-modified set) — only run credo/spex against those.
2. **Skip when no `.ex`/`.exs` files were touched** this turn.
3. **Distinguish "introduced this turn" vs "pre-existing"** in the report
   and only block on the former; surface pre-existing as informational.

### Expected

A turn that only edits docs / `.code_my_spec/` content should not be gated
on lint debt in unrelated `lib/` files.

---

## 5. Stop hook re-fires stale spex failures from prior session transcripts (framework)

**Scope:** framework
**Severity:** medium
**Captured:** 2026-05-17 (MCP `create_issue` returning `-32603 Internal error`
at capture, so filed here per the documented fallback.)

### What we saw

Stop hook reports the same two spex failures on every turn-end:

- `test/spex/672_sign_up_and_sign_in_with_google/criterion_5679_new_visitor_signs_up_via_google_in_one_click_spex.exs:96`
  - `protocol Enumerable not implemented for Atom`
- `test/spex/672_sign_up_and_sign_in_with_google/criterion_5681_user_changes_google_email_and_still_resolves_to_the_same_mms_account_spex.exs:50`
  - same error

These do not reproduce. Verified during this turn:

1. `mix spex` on each file individually — 0 failures.
2. Both files together — 2 tests, 0 failures.
3. Full `mix spex` suite — 324 tests, 0 failures.
4. `mix credo --strict` — 0 issues.
5. Manually POSTing a Stop event to the hook server (`curl -X POST
   http://localhost:4003/api/hooks/stop ...`) returns `{}` (no blockers).
6. `.code_my_spec/internal/agent_test_events.json` `for_callers` is `[]`
   and only contains success events for 5679.

The error string "Enumerable not implemented for Atom" only appears in
old transcript jsonl files under
`/Users/johndavenport/.claude/projects/-Users-johndavenport-Documents-github-market-my-spec/*.jsonl`,
suggesting the hook is sourcing failures from session transcripts rather
than the live test-event JSON.

### Relationship to prior issues

This is a recurrence of resolved issue
`5efd7331-64a0-4f8d-927f-fc7e84a9f63f` ("Stop hook re-fires stale spex
failures after fixture commit f724220"). It also overlaps with item 4
above ("Stop hook blocks on pre-existing credo/spex unrelated to turn
changes"). Resolution of `5efd7331` evidently regressed.

### Impact

Turn-end is blocked indefinitely on errors that do not reproduce. The
model has no clean exit path: re-running spex doesn't clear the report,
no incoming or accepted issues exist that the supposed failures could
hang off of, and `create_issue` itself is returning `-32603` so the
framework escape hatch is also dead.

### Suggested fix directions

1. Source spex failure reporting from `agent_test_events.json` (or
   whatever the current run wrote) rather than session transcripts. If
   the latest run shows no failures, the hook should not surface old
   ones.
2. Add a TTL or run-id check so failure reports older than the most
   recent `completed_at` timestamp are discarded.
3. Expose a hook-side endpoint (e.g. `POST /api/hooks/clear-stale`) so
   the model can request a re-scrape after manually verifying that
   flagged failures no longer reproduce.

---

## Surfaced threads worth a draft pass (CMS-track)

Captured here so they don't get lost while issues are pending. These came
out of the local scan run; staged touchpoints noted.

Note: dates are 2026-05-17 surface, not 2025.

| Source           | Score | Replies | Title |
|------------------|-------|---------|-------|
| r/ClaudeAI       | 170   | 28      | "Anthropic shipped 4 context tools between /clear and /compact. Here's when each one wins" |
| r/ClaudeAI       | 109   | 24      | "Converted Karpathy's coding skill from Pro to free plan" |
| r/ClaudeAI       | 83    | 38      | "Building a 'Zero-Waste' SDLC: How to drive Development from QA Specs" |
| r/ClaudeAI       | 63    | 21      | "I replicated Anthropic's Generator-Evaluator harness…" |
| r/ClaudeAI       | 52    | 3       | "Building something with a lot of code? Tips from Anthropic" (staged ✓) |
| r/ClaudeAI       | 17    | 9       | "Non-coders of r/ClaudeAI, what have you actually shipped?" |
| r/ClaudeAI       | 11    | 15      | "I tested how well Claude generated code handles security" |
| r/elixir         | 53    | 14      | "Phoenix is magic → what is this macro doing?" (staged ✓) |
| r/elixir         | 39    | 7       | "I ported claw-code to Elixir and leaned into OTP" |
| r/ChatGPTCoding  | 24    | (var)   | "Stop letting your AI 'hallucinate' your architecture" |
