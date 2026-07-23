# Refresh a persisted Reddit Thread's full content for the LLM

As a solo founder, I want the LLM to refresh a specific Reddit thread's full content — OP body, comment tree (preserving Reddit's order), scores, authors, timestamps — into our persisted Thread record, so it can give me grounded engagement advice before I dictate a response.

The agent calls a `get_thread(thread_id: UUID)` MCP tool with a UUID returned from a prior `search_engagements` / `run_search` candidate (story 705 — every candidate is a persisted Thread row). The app fetches Reddit's `/comments/<source_thread_id>.json`, normalizes the JSON into our internal schema (preserving comment hierarchy), and **updates the persisted Thread row in place**: `op_body`, `comment_tree` (jsonb), `raw_payload` (jsonb), `fetched_at` (now), and `last_activity_at` (newest comment timestamp — the field story 705's R8 reads for recency). Returns the updated Thread.

Comment order inside `comment_tree` preserves Reddit's response order (confidence/hot at top level, chronological within sub-trees by default) — what a user sees in the Reddit UI.

Repeat fetches within a 5-minute freshness window read the cached row instead of re-hitting Reddit. The agent decides when to call; the cache just optimizes redundant calls within the window. Outside the window, the row is refreshed in place (same UUID).

Platform errors (429, 5xx, network) surface as a usable error response — the persisted Thread row's existing data is preserved (no destructive write on failure).

ElixirForum (Discourse) coverage is in story 714. This story is Reddit-only so it can land cleanly with the same ReqCassette + canonical Anubis testing pattern story 705 established.

This is story 2 of 3 in the engagement-finder loop. Stories 705 (search → Thread refs) and 707 (stage polished draft) bracket it.

Redesigned 2026-05-16 — the original criteria assumed `(source, thread_id_string)` input. The new model: the Thread is already persisted (story 705 upserts it on search), so `get_thread` takes a UUID and refreshes the row with full content. This closes the natural agent loop: search returns Thread refs → user picks → `get_thread(uuid)` → `stage_response(uuid, ...)`.

## Meta
- id: 497ab7d2-64e8-4df3-a1e0-2629fd3e7233
- number: 706
- status: in_progress
- component: MarketMySpecWeb.ThreadLive
- personas: agent, founder

## Rules

### get_thread(thread_id: UUID) looks up the Thread by UUID (account-scoped), refreshes it from Reddit when the freshness window has expired, and returns the updated Thread struct.

#### happy: Agent calls get_thread on a never-deep-read Thread; full content is fetched and returned [e2ac1bb3]
Given Sam's account has Thread T persisted from a prior scan (op_body nil, comment_tree empty, raw_payload empty, last_activity_at nil, fetched_at nil)
When the agent calls get_thread(thread_id: T.id)
Then the cassette returns Reddit's /comments/<source_thread_id>.json payload (post + comments)
And the response is the updated Thread struct with op_body, comment_tree, raw_payload, last_activity_at, and fetched_at all populated
And T.id is unchanged

### Reddit's comments JSON is normalized into comment_tree (jsonb) preserving Reddit's response order at every level (confidence/hot at top level, chronological within sub-trees); each comment carries author, body, score, created_utc, and depth.

#### happy: comment_tree preserves Reddit's order and per-comment fields including depth [3ef14906]
Given the cassette returns a Reddit thread with three top-level comments in Reddit's order C1, C2, C3 (C1 highest scored, C3 lowest), with C2 having two nested replies R1 and R2 in Reddit's reply order
When the agent calls get_thread(T.id)
Then comment_tree top-level entries appear in the order [C1, C2, C3]
And C2's children appear in the order [R1, R2]
And each comment in the tree carries author (string), body (string), score (integer), created_utc (timestamp), and depth (integer — 0 for top-level, 1 for direct replies, etc.)

### Refresh updates the existing Thread row in place — op_body, comment_tree, raw_payload, fetched_at, and last_activity_at change but the Thread UUID never does, and no duplicate row is created.

#### happy: Two refresh calls separated by freshness expiry update the same row in place [363cc5cb]
Given Sam's account has one Thread row T with last fetched_at 6 minutes ago (outside the 5-minute window)
And the threads table contains exactly one row for this source_thread_id
When the agent calls get_thread(T.id) and the cassette returns updated content
Then T's UUID is unchanged
And T's op_body, comment_tree, raw_payload, fetched_at, and last_activity_at are all updated
And the threads table still contains exactly one row for this source_thread_id (no duplicate created)

### Within a 5-minute freshness window of the last successful fetch, repeat get_thread calls on the same UUID return the cached row without making an HTTP call to Reddit; outside the window, get_thread re-fetches.

#### happy: Repeat call within 5-minute window returns cached row without an HTTP call [ad28605c]
Given Thread T was successfully fetched 30 seconds ago (fetched_at = now - 30s)
And the cassette is configured with no interactions for /comments/<source_thread_id>.json
When the agent calls get_thread(T.id)
Then the response is T's existing data
And no HTTP request is made to Reddit (cassette in :replay mode would raise on an unrecorded request)
And T's fetched_at is unchanged

### Default page caps top-level comments at 25 and the response carries a comments_cursor (or nil) for the next page.

#### happy: Thread with 40 top-level comments returns 25 plus a cursor for the rest [c887b349]
Given the cassette returns a Reddit thread with 40 top-level comments (none replied to)
When the agent calls get_thread(T.id) with no cursor
Then comment_tree contains exactly 25 top-level entries
And the response carries a non-nil comments_cursor token
When the agent calls get_thread(T.id, cursor: comments_cursor)
Then comment_tree contains the remaining 15 top-level entries
And the response's comments_cursor is nil

### When a refresh attempt fails (HTTP 429, 5xx, or network failure), the persisted Thread row is preserved unchanged and the response returns the cached data with a stale_warning carrying reason and age_seconds.

#### failure: Outside-window refresh returns 429; response serves stale cached data with a flag [b9099e50]
Given Thread T was last fetched 10 minutes ago (fetched_at = now - 600s) with op_body, comment_tree, and raw_payload populated
And the cassette returns HTTP 429 for the refresh call
When the agent calls get_thread(T.id)
Then the response includes T's existing op_body, comment_tree, raw_payload (the cached data)
And the response carries a stale_warning map with reason :rate_limited and age_seconds approximately 600
And the persisted Thread row in the DB is unchanged (fetched_at still = now - 600s)
And no exception is raised

### When Reddit returns valid HTTP but the payload fails to fully normalize, raw_payload and fetched_at are written, comment_tree falls back to its prior value (or nil if never populated), and the normalization error is surfaced in the response alongside the partially-updated Thread.

#### failure: Reddit returns 200 with malformed comment shape; raw_payload persists, comment_tree falls back to prior [f2f19dde]
Given Thread T was last fetched 10 minutes ago with a previously-populated comment_tree of 3 comments
And the cassette returns HTTP 200 with a body where data.children is present but malformed (e.g., a comment entry missing required keys author and body)
When the agent calls get_thread(T.id)
Then T's raw_payload is updated to the new (malformed) JSON
And T's fetched_at is updated to now
And T's comment_tree is unchanged (still the prior 3 comments)
And the response carries a normalization_error map describing what failed (e.g., :missing_required_fields with the affected keys)
And the response still includes the partially-updated Thread struct

### get_thread on a UUID owned by a different account returns :not_found and leaks no thread data.

#### happy: Account B's call for Account A's Thread returns :not_found and triggers no HTTP [1c5c9790]
Given Thread T-a is owned by Account A with populated content
And Dave is signed in on Account B (not a member of A)
And the cassette is configured with no interactions
When Dave's agent calls get_thread(T-a.id)
Then the response is {:error, :not_found}
And no HTTP request is made to Reddit (no cassette interaction consumed)
And T-a in the DB is unchanged
