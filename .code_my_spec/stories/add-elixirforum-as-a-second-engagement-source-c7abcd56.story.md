# Add ElixirForum as a second engagement source

As a solo founder, I want the engagement-finder to also pull from ElixirForum (Discourse) alongside Reddit, so my candidate list covers both platforms behind a unified Source behaviour without me having to choose between them.

This builds on story 705 (Reddit-only) by adding the Discourse adapter — venue identifier format is `category-slug` or `category-slug:tag`, JSON normalization maps Discourse `/c/<slug>/<id>.json` topics into the common candidate shape (title, source, url, score, reply_count, recency, snippet), and the cross-source orchestrator assertions (failure isolation, shape parity, interleave) become testable end-to-end.

Split out from story 705 on 2026-05-16 so Reddit could land cleanly first.

## Meta
- id: c7abcd56-0b68-4379-9d5b-16bcbbea6726
- number: 714
- status: in_progress
- component: MarketMySpecWeb.McpController
- personas: agent, founder

## Rules

### Reddit and ElixirForum adapters implement the same Engagements.Source behaviour callbacks (validate_venue/1, search/3, get_thread/2, post/3) so adding a third source means writing one new adapter module with no orchestrator changes.

#### happy: Both adapter modules implement the Source behaviour and the orchestrator dispatches by venue.source [f28d5d84]
Given the Engagements.Source behaviour declares the callbacks validate_venue/1, search/3, get_thread/2, post/3
And Engagements.Source.Reddit implements all four callbacks
And Engagements.Source.ElixirForum implements all four callbacks
When the orchestrator (Engagements.Search.search/3) dispatches venues whose source is :reddit
Then the call routes to Engagements.Source.Reddit
When the orchestrator dispatches venues whose source is :elixirforum
Then the call routes to Engagements.Source.ElixirForum
And the orchestrator contains no source-specific branches beyond the source-to-module mapping

### An ElixirForum venue's identifier is "category-slug" or "category-slug:tag" per Discourse semantics; validate_venue/1 accepts both forms and rejects empty, nil, or malformed identifiers.

#### happy: validate_venue accepts category-slug and category-slug:tag; rejects malformed [d9927866]
Given Engagements.Source.ElixirForum.validate_venue/1
When called with "elixir"
Then it returns :ok
When called with "elixir:testing"
Then it returns :ok
When called with ""
Then it returns {:error, message} where message is a human-readable string
When called with nil
Then it returns {:error, message}
When called with "category with spaces"
Then it returns {:error, message}

### Discourse's /c/<slug>/<id>.json (and tag-scoped variants) is normalized into Thread rows with the same field set Reddit produces: source :elixirforum, source_thread_id (topic id), url, title, score (like_count), reply_count (posts_count - 1), recency (last_posted_at), snippet (excerpt).

#### happy: Discourse latest.json normalizes to Thread rows with the canonical field set [19ea1e38]
Given a cassette returns Discourse's /c/elixir/latest.json with two topics: T1 (id 42, title "Phoenix LiveView form patterns", like_count 7, posts_count 4, last_posted_at "2026-05-10T12:00:00Z", excerpt "I've been...") and T2 (id 43, title "Ash incremental migration", like_count 3, posts_count 2, last_posted_at "2026-05-09T08:00:00Z", excerpt "Adopting Ash...")
And Sam's account has an enabled ElixirForum venue with identifier "elixir"
When the agent calls search_engagements with query "elixir"
Then two Thread rows are upserted on the account, one per topic
And the Thread for T1 carries: source :elixirforum, source_thread_id "42", url "https://elixirforum.com/t/42", title "Phoenix LiveView form patterns", score 7, reply_count 3, recency ~U[2026-05-10 12:00:00Z], snippet "I've been..."
And the Thread for T2 carries the same field set with its own values
And each candidate in the response carries the Thread UUID alongside these fields

### A Reddit candidate and an ElixirForum candidate in the same response are indistinguishable in field shape; the agent renders the unified list without branching on source.

#### happy: Reddit and ElixirForum candidates in one response have identical key sets [58a58507]
Given Sam's account has one enabled Reddit venue (r/elixir) and one enabled ElixirForum venue (elixir)
And the Reddit cassette returns one post
And the ElixirForum cassette returns one topic
When the agent calls search_engagements with query "elixir"
Then the response candidates list contains exactly two entries
And the key set of the Reddit candidate is identical to the key set of the ElixirForum candidate (e.g., both have thread_id, source, title, url, score, reply_count, recency, snippet, engagement)
And the only field-level difference is the values themselves (source = :reddit vs :elixirforum, etc.)

### If one source fails (e.g., Reddit 429) and another succeeds (ElixirForum 200), the response carries the successful source's candidates plus a per-venue failure entry for the failed source; no exception is raised.

#### happy: Reddit 429 plus ElixirForum 200: response has the ElixirForum thread and a Reddit failure entry [ea9014ba]
Given Sam's account has one enabled Reddit venue (r/elixir) and one enabled ElixirForum venue (elixir)
And the Reddit cassette returns HTTP 429
And the ElixirForum cassette returns HTTP 200 with one topic
When the agent calls search_engagements with query "elixir"
Then the response candidates list contains exactly one entry: the ElixirForum Thread
And the response failures list contains exactly one entry referencing the Reddit r/elixir venue
And no exception is raised

### If every venue across every source fails, the response carries an empty candidates list plus per-venue failure entries — no exception is raised.

#### failure: Every venue across every source 5xx: empty candidates plus per-venue failure entries [7f9b8ae8]
Given Sam's account has one enabled Reddit venue (r/elixir) and one enabled ElixirForum venue (elixir)
And both cassettes return HTTP 500
When the agent calls search_engagements with query "elixir"
Then the response candidates list is empty
And the response failures list contains exactly two entries: one for the Reddit venue and one for the ElixirForum venue
And no exception is raised

### Candidates from different sources rank together by venue.weight times per-source signal descending, with no source-priority bias — a high-weight ElixirForum venue can outrank a low-weight Reddit venue.

#### happy: High-weight ElixirForum candidate outranks low-weight Reddit candidate with same per-source signal [e2ca7718]
Given Sam's account has one enabled Reddit venue (r/elixir, weight 1.0) and one enabled ElixirForum venue (elixir, weight 3.0)
And the Reddit cassette returns one post with score 10 and num_comments 0
And the ElixirForum cassette returns one topic with like_count 10 and posts_count 1 (so reply_count = 0)
When the agent calls search_engagements with query "elixir"
Then the response candidates list contains exactly two entries
And the ElixirForum candidate appears first (rank ≈ 3.0 × 10 = 30)
And the Reddit candidate appears second (rank ≈ 1.0 × 10 = 10)
And the source field is not used as a tiebreaker

### Each failure entry in the response envelope carries source (atom), venue_identifier (string), and a human-readable reason string suitable for direct display in agent prose or LiveView output — no raw exception dumps.

#### happy: Failure entries carry source, venue_identifier, and a human-readable reason [c774a91a]
Given Sam's account has one Reddit venue (r/elixir) returning 429, one ElixirForum venue (elixir) returning 500, and one Reddit venue (r/programming) whose cassette is configured to drop the connection mid-response
When the agent calls search_engagements with query "elixir"
Then the response failures list contains three entries
And the first entry has source :reddit, venue_identifier "elixir", reason "HTTP 429 — rate limited"
And the second entry has source :elixirforum, venue_identifier "elixir", reason "HTTP 500 — server error"
And the third entry has source :reddit, venue_identifier "programming", reason matching /network/i (a human-readable network failure message, not a raw Erlang error tuple)
And no reason string contains the substring "%Req.TransportError" or other inspect-formatted error dump
