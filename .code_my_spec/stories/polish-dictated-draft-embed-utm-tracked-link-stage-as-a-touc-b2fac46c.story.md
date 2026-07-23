# Polish dictated draft, embed UTM-tracked link, stage as a Touchpoint

As a solo founder, I want the LLM to polish my dictated rough draft, embed a UTM-tracked link to the right page, and stage it as a Touchpoint I can copy from the UI — so I can engage in seconds (dictate → polish → copy → paste).

The agent calls `stage_response(thread_id: UUID, polished_body, link_target, angle?)` MCP tool. `thread_id` is the Thread UUID from a prior `search_engagements` / `run_search` call (story 705 — every candidate is a persisted Thread row). The app rewrites `link_target` with a per-source UTM scheme (Reddit: `utm_source=reddit&utm_medium=comment&utm_campaign=<subreddit>`; ElixirForum: `utm_source=elixirforum&utm_medium=reply&utm_campaign=<category-slug>`), embeds the UTM-tracked link into the body at the position the agent placed `link_target`, and creates a Touchpoint with state `:staged` (story 716 owns the lifecycle). Returns the new Touchpoint id.

The polishing itself (preserving Sam's voice, tone, length) happens in the agent's chat with Sam BEFORE `stage_response` is called — the tool receives the agreed-upon polished body and trusts it. The tool is not a content rewriter; it's a UTM-embedder + Touchpoint-creator.

Touchpoint review, edit, copy-to-clipboard, and mark-posted all happen in TouchpointLive.Show (story 716). 707 owns the polish-and-stage entry; 716 owns the lifecycle and UI.

**v1 has no programmatic posting.** Reddit's Responsible Builder Policy (effective May 2026) makes commercial automated posting require explicit written approval. The manual-paste design (Sam copies the polished body and posts it himself) sidesteps the entire policy by never making MMS an "app" on Reddit's API. Deferred indefinitely. See `.code_my_spec/knowledge/reddit-api.md` for the policy decision.

This is story 3 of 3 in the engagement-finder loop. Stories 705 (Thread-backed search) and 706 (deep read by UUID) feed into it; story 716 (Touchpoint lifecycle) owns the post-stage flow.

Redesigned 2026-05-16 — the original criteria assumed Touchpoint state was implicit from `posted_at`/`comment_url` presence, and 707 owned the UI flows. The new split: 705 provides Thread UUIDs, 716 owns explicit Touchpoint state + UI, 707 owns the polish-and-stage entry point + UTM embedding.

## Meta
- id: b2fac46c-555d-4ba0-8e9e-ad6161550884
- number: 707
- status: in_progress
- component: MarketMySpecWeb.ThreadLive
- personas: agent, founder

## Rules

### stage_response(thread_id, polished_body, link_target, angle?) creates an account-scoped Touchpoint and returns its id.

#### happy: Agent calls stage_response and receives the new Touchpoint id [093094b5]
Given Sam's account has a Thread T (source :reddit, persisted from a prior search)
When the agent calls stage_response(thread_id: T.id, polished_body: "Here's a thought — see https://marketmyspec.com/example for the full pattern.", link_target: "https://marketmyspec.com/example")
Then the response is {:ok, touchpoint_id} where touchpoint_id is a UUID
And the touchpoints table contains a new row with id touchpoint_id
And the new row's account_id matches Sam's account
And the new row's thread_id matches T.id

### link_target is rewritten with a per-source UTM scheme derived from the parent Thread's source: Reddit uses utm_source=reddit&utm_medium=comment&utm_campaign=<subreddit>; ElixirForum uses utm_source=elixirforum&utm_medium=reply&utm_campaign=<category-slug>.

#### happy: Reddit and ElixirForum threads get distinct UTM schemes derived from the parent Thread's source [50d880c8]
Given Sam's account has a Reddit Thread T-reddit (source :reddit, subreddit "elixir") and an ElixirForum Thread T-forum (source :elixirforum, category "phoenix-forum")
When the agent calls stage_response(thread_id: T-reddit.id, polished_body: "See https://marketmyspec.com/article for details.", link_target: "https://marketmyspec.com/article")
Then the resulting Touchpoint's polished_body contains the substring "utm_source=reddit"
And it contains "utm_medium=comment"
And it contains "utm_campaign=elixir"
When the agent calls stage_response(thread_id: T-forum.id, polished_body: "See https://marketmyspec.com/article for details.", link_target: "https://marketmyspec.com/article")
Then the resulting Touchpoint's polished_body contains "utm_source=elixirforum"
And it contains "utm_medium=reply"
And it contains "utm_campaign=phoenix-forum"

### The UTM-tracked link is embedded in polished_body at the position the agent placed the original link_target substring; the result is stored as the Touchpoint's polished_body as plain text (no HTML, no transformations beyond platform-native markdown).

#### happy: UTM-tracked link replaces the original link_target at the same position; surrounding text unchanged [e018576b]
Given Sam's account has a Reddit Thread T (subreddit "elixir")
And the agent has a polished_body "I had the same issue. https://marketmyspec.com/example explains why — happy to dig deeper if useful."
When the agent calls stage_response(thread_id: T.id, polished_body: above, link_target: "https://marketmyspec.com/example")
Then the Touchpoint's polished_body equals "I had the same issue. https://marketmyspec.com/example?utm_source=reddit&utm_medium=comment&utm_campaign=elixir explains why — happy to dig deeper if useful."
And no HTML tags appear in the polished_body
And the surrounding sentence is byte-identical apart from the UTM additions on the link itself

### The original un-UTM-modified link_target URL is preserved on the Touchpoint as link_target for reference and audit, separate from the embedded UTM-tracked version inside polished_body.

#### happy: Original link_target preserved on the Touchpoint alongside the UTM-embedded body [80761969]
Given Sam's account has a Reddit Thread T (subreddit "elixir")
When the agent calls stage_response(thread_id: T.id, polished_body: "See https://marketmyspec.com/x", link_target: "https://marketmyspec.com/x")
Then the resulting Touchpoint's link_target field equals "https://marketmyspec.com/x" (no UTM params)
And the Touchpoint's polished_body contains "https://marketmyspec.com/x?utm_source=reddit&utm_medium=comment&utm_campaign=elixir"
And link_target and the embedded URL in polished_body are independently queryable

### Cross-account access: stage_response with a thread_id owned by another account returns :not_found and creates no Touchpoint.

#### failure: Account B calling stage_response on Account A's Thread returns :not_found [bdadfcd6]
Given Account A has a Thread T-a
And Dave is signed in on Account B (no membership in Account A)
And Account B has zero existing Touchpoints
When Dave's agent calls stage_response(thread_id: T-a.id, polished_body: "anything", link_target: "https://marketmyspec.com/anything")
Then the response is {:error, :not_found}
And the touchpoints table contains zero rows scoped to Account B
And the touchpoints table contains zero rows referencing T-a.id
And no exception is raised

### stage_response makes no platform API call (no Reddit submit, no Discourse post) — v1 only creates the Touchpoint row.

#### happy: stage_response makes zero HTTP calls to Reddit or ElixirForum [a96d35ac]
Given Sam's account has a Reddit Thread T
And ReqCassette is configured in :replay mode with zero recorded interactions for reddit.com and elixirforum.com
When the agent calls stage_response(thread_id: T.id, polished_body: "...", link_target: "https://marketmyspec.com/x")
Then the response is {:ok, touchpoint_id}
And the cassette consumed zero interactions (no HTTP request was made to either reddit.com or elixirforum.com)
And no exception was raised about an unmatched HTTP request

### The Touchpoint created by stage_response inherits story 716's lifecycle defaults — state :staged on create, with the optional angle persisted when provided and nil when omitted.

#### happy: Touchpoint defaults to :staged; angle persists when provided, nil when omitted [1938c57a]
Given Sam's account has a Reddit Thread T
When the agent calls stage_response(thread_id: T.id, polished_body: "...", link_target: "https://marketmyspec.com/x") with NO angle argument
Then the resulting Touchpoint has state :staged
And the Touchpoint's angle field is nil
When the agent calls stage_response(thread_id: T.id, polished_body: "...", link_target: "https://marketmyspec.com/y", angle: "intro harness eng as the missing piece")
Then the resulting Touchpoint has state :staged
And the Touchpoint's angle field equals "intro harness eng as the missing piece"

## Questions
- [open] UTM campaign extraction: do we (a) parse subreddit/category-slug from Thread.url (works for Reddit, may need richer URL data for ElixirForum), (b) add a venue_id FK on Thread so we look up Venue.identifier directly, or (c) store campaign_tag on Thread at upsert time during search? Affects Thread schema (706 / 705 territory) and the stage_response implementation here. Pin before implementation.
