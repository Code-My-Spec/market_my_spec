# Discover Reddit engagement opportunities (Thread-backed)

As a solo founder, I want the LLM to scan Reddit for high-intent engagement opportunities, persist what it finds as durable Thread records, and surface my prior engagement history alongside each candidate — so the agent can triage across sessions ("we already commented here Tuesday, our angle was X") instead of treating every scan as a cold start.

The LLM is the actor: it calls a `search_engagements` MCP tool (or `run_search` for a saved query), the app fans out to each enabled Reddit venue, **upserts a Thread row per result** keyed by `(account_id, source, source_thread_id)`, and returns a ranked candidate list where each entry is a Thread reference (UUID + summary metadata + engagement history). The Thread is the durable entity that accumulates state across scans and across sessions — score/num_comments/last_activity_at refresh on every scan; op_body/comment_tree/raw_payload land later when `get_thread` runs (story 706).

Each candidate also carries an `engagement` summary derived from the Thread's Touchpoints (story 715): `count`, `latest_state` (staged/posted/abandoned), `latest_angle`, `latest_posted_at`. Empty/nil when the thread has no touchpoints yet. The LLM uses this to decide "fresh thread to consider" vs "thread we already engaged with — re-engage or skip."

Multi-source coverage (ElixirForum) is in story 714 — this story is Reddit-only so it can land cleanly. Multi-venue behavior (multiple subreddits) still exercises every fan-out / dedup / ranking path in the orchestrator.

This is story 1 of 3 in the engagement-finder loop. Stories 706 (deep read by UUID) and 707 (stage polished draft) build on top.

Redesigned 2026-05-16 — the initial ship returned ephemeral candidate maps. The model changed to "every candidate is a persisted Thread ref" so the agent has stable UUIDs across turns and the engagement summary join is cheap. Existing search behavior (rank, dedup, page cap, failure isolation) is unchanged — what changes is that candidates are now Thread rows, not maps.

## Meta
- id: 3efa638e-1cac-4b95-987a-d7e29cbe43a4
- number: 705
- status: in_progress
- component: MarketMySpecWeb.McpController
- personas: agent, founder

## Rules

### Every candidate surfaced by a search is persisted as a Thread row, and re-running the same search updates the existing row without creating duplicates.

#### happy: Re-running the same search updates existing Thread rows instead of duplicating them [ac449b7a]
Given Sam's account has a single enabled venue r/elixir
And the Reddit search adapter returns two posts (source_thread_id "t3_aaa" and "t3_bbb")
When Sam runs the saved search "agentic coding" for the first time
Then two Thread rows are persisted on the account, one per source_thread_id
And each candidate in the response carries its Thread UUID
When Sam runs the same saved search a second time and the adapter returns the same two posts
Then the same two Thread UUIDs are returned in the response
And no new Thread rows are created
And each Thread's last_seen_at is refreshed to the second-run timestamp

#### failure: A malformed listing entry is skipped without poisoning the rest of the batch [d214a62a]
Given Sam's account has an enabled venue r/elixir
And the Reddit search adapter returns three posts where the middle one is missing source_thread_id
When Sam runs the search
Then two Thread rows are persisted (one per valid post)
And the malformed entry is skipped (no Thread row, no candidate in the response)
And the response succeeds (no exception, no per-venue failure entry)

### Search returns only candidates from the calling account's venues.

#### happy: Account A's search never surfaces Account B's venues or Threads [87e07777]
Given Account A has venue r/elixir with a previously-persisted Thread T-a
And Account B has venue r/programming with a previously-persisted Thread T-b
When Sam, signed in to Account A, runs a search
Then only Account A's venues are queried by the orchestrator
And the response contains only candidates whose Thread.account_id equals Account A's id
And no Thread, venue, or failure entry references Account B

### Only enabled venues are queried; disabled venues are skipped entirely with no HTTP call.

#### happy: Disabled venues are never queried and never surface candidates [ddf1ca8c]
Given Sam's account has two venues: r/elixir (enabled) and r/programming (disabled)
When Sam runs a search
Then the orchestrator issues exactly one HTTP call, to r/elixir
And no HTTP request is made to r/programming
And the response contains only candidates derived from r/elixir
And the response's failures list is empty

### A failing venue does not abort the search; healthy venues still return candidates and each failure is reported in the response envelope.

#### happy: One venue rate-limited; healthy venue's candidates still surface [3739ef36]
Given Sam's account has two enabled venues: r/elixir and r/programming
And r/elixir's adapter returns 200 with one post
And r/programming's adapter returns 429
When Sam runs the search
Then the response's candidates list contains the one Thread from r/elixir
And the response's failures list contains an entry for r/programming with the 429 reason
And no exception is raised

#### failure: All venues fail; response is empty candidates plus per-venue failure entries [c698d23f]
Given Sam's account has two enabled venues: r/elixir and r/programming
And both venues' adapters return 5xx
When Sam runs the search
Then the response's candidates list is empty
And the response's failures list contains one entry per failed venue, each with the venue identifier and reason
And no exception is raised

### Candidates rank deterministically by venue weight times per-source signal descending, deduplicate by URL with the highest-weight venue winning attribution, and produce identical UUIDs and ordering across repeat calls with the same inputs.

#### happy: Higher-weight venue's candidate ranks first; repeat calls return identical UUIDs and ordering [6166f929]
Given Sam's account has two enabled venues: r/elixir (weight 2.0) and r/programming (weight 1.0)
And each adapter returns one candidate with identical per-source signal (score 10, num_comments 2)
When Sam runs the search
Then the r/elixir candidate appears first in the ranked list
And the r/programming candidate appears second
When Sam runs the same search a second time against the same adapter responses
Then the candidate list contains the same Thread UUIDs in the same order

### Each candidate carries an engagement summary derived from the Thread's Touchpoints (count, latest_state, latest_angle, latest_posted_at), with latest_state chosen by the most recently inserted Touchpoint; all fields are nil or zero when no Touchpoints exist.

#### happy: Engagement summary reflects Touchpoint history; latest by inserted_at; zeroed when none exist [484b8eb3]
Given Sam's account has an enabled venue r/elixir
And Thread T-fresh has been seen before but has zero Touchpoints
And Thread T-engaged has two Touchpoints: an earlier staged one and a later posted one with angle "intro harness eng" posted last Tuesday (so the posted Touchpoint has the higher inserted_at)
And both threads surface in the adapter response
When Sam runs the search
Then T-fresh's candidate carries engagement: count=0, latest_state=nil, latest_angle=nil, latest_posted_at=nil
And T-engaged's candidate carries engagement: count=2, latest_state=:posted, latest_angle="intro harness eng", latest_posted_at=last Tuesday

### Each source returns up to 25 candidates per page, and the response carries a single opaque next_cursor token for the next batch.

#### happy: First page returns 25 candidates plus a cursor; cursor fetches the remainder [83618e63]
Given Sam's account has an enabled venue r/elixir
And the venue's listing contains 30 posts matching the query
When Sam runs the search with no cursor
Then the response's candidates list contains exactly 25 candidates
And the response carries a next_cursor token (non-nil opaque string)
When Sam runs the search a second time passing that next_cursor
Then the response's candidates list contains the remaining 5 candidates
And the response's next_cursor is nil

### Recency reflects time of last known activity on the thread, using Thread.inserted_at as the v1 proxy and Thread.last_activity_at when a deep-dive has populated it.

#### happy: Recency falls back to inserted_at; deep-dived threads use last_activity_at when set [51ce952f]
Given Sam's account has an enabled venue r/elixir
And Thread T-cold was first persisted 2 days ago with no last_activity_at populated
And Thread T-deep was first persisted 3 days ago and a deep-dive 5 minutes ago set its last_activity_at to that time
And both threads surface in the search response
When Sam runs the search
Then T-cold's candidate recency equals T-cold's inserted_at (2 days ago)
And T-deep's candidate recency equals T-deep's last_activity_at (5 minutes ago)

## Questions
- [resolved] How are per-source signals (Reddit upvotes vs Discourse likes vs reply counts) normalized for cross-source ranking? Different absolute scales — does the ranker rescale to a 0-1 range per source, use a logarithmic transform, or rank within source first and then interleave?
- [resolved] What is the result limit per call — does the LLM page through results, or does the response cap at N candidates? Default N?
- [resolved] Is there a freshness filter (e.g., only threads &lt; 48h old), or does the LLM filter for recency itself from the returned `recency` field? If a filter exists, is it a search parameter or a hardcoded cutoff?
