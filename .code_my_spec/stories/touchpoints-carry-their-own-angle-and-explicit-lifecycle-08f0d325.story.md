# Touchpoints carry their own angle and explicit lifecycle

As a solo founder, I want every comment I draft on a thread to be a discrete lifecycle-aware record — with its own angle and an explicit state (staged, posted, or abandoned) — so my agent has structured history to reference when the same thread surfaces again, and so I can revise/recover drafts without losing context.

Today the Touchpoint schema is implicit: `comment_url + posted_at present` means posted; both absent means staged. There's no field for "the agent's reasoning for this specific comment," no way to mark "we drafted this and decided not to post," and no agent-side tool to list prior touchpoints for a thread.

This story makes the Touchpoint lifecycle explicit and gives the agent the tools to read its own history.

**Why angle is per-Touchpoint, not per-Thread:** we may comment on the same thread multiple times (initial reply, then a follow-up days later when the OP responds). Each reply has its own angle because the conversation has evolved. The Thread is the durable engagement target; the Touchpoint is the discrete event with its own context.

**Schema additions** (on `touchpoints`):
- `state :: enum [:staged, :posted, :abandoned]` — defaults to `:staged` on create
- `angle :: text` — optional, the agent's reasoning for this specific comment

Existing rows backfill: `state = :posted` where `posted_at` is not null, else `:staged`.

**Tool surface additions:**
- `stage_response` gains an optional `angle` param (not required — agent can stage without one)
- `update_touchpoint(touchpoint_id, state, comment_url \\ nil, posted_at \\ nil)` — transitions state; the LiveView "paste live URL" flow uses the same underlying context function
- `list_touchpoints(thread_id)` — returns all touchpoints for a thread, newest first, with state/angle/polished_body/comment_url/posted_at/inserted_at

This enables story 705's engagement summary (which reads from `touchpoints` to populate `count`, `latest_state`, `latest_angle`, `latest_posted_at` per candidate).

Carved out 2026-05-16 from the broader 705 redesign — search-side work stays in 705; the Touchpoint lifecycle is its own slice with its own schema migration.

## Meta
- id: 08f0d325-e66f-481e-a4e6-6eb4c4d78a60
- number: 716
- status: in_progress
- component: MarketMySpecWeb.TouchpointLive
- personas: agent, founder

## Rules

### Every Touchpoint has an explicit state in {:staged, :posted, :abandoned}, defaulting to :staged on create, with transitions permitted in any direction.

#### happy: Touchpoint state moves freely through staged, posted, abandoned, and back [30ed9ac6]
Given Sam's account has a thread T with no Touchpoints
When the agent calls stage_response on T with a polished body
Then a Touchpoint is created with state :staged
When the agent calls update_touchpoint on it with state :posted, comment_url, and posted_at
Then the Touchpoint's state is :posted
When Sam deletes the comment on Reddit and the agent calls update_touchpoint with state :abandoned
Then the Touchpoint's state is :abandoned
When Sam decides to revive the draft and the agent calls update_touchpoint with state :staged
Then the Touchpoint's state is :staged again
And the Touchpoint id and angle and polished_body are unchanged across every transition

### Each Touchpoint may carry an optional angle text capturing the agent's reasoning for this specific comment; angle is never required.

#### happy: stage_response persists angle when given; leaves it nil when omitted [f2a538c8]
Given Sam's account has a thread T
When the agent calls stage_response on T with a polished body and no angle parameter
Then a Touchpoint is created with polished_body set and angle nil
When the agent calls stage_response on T again with a polished body AND angle "intro harness eng as the missing piece"
Then a second Touchpoint is created with polished_body set and angle equal to "intro harness eng as the missing piece"
And both Touchpoints are valid (the changeset accepts angle being absent on the first and present on the second)

### A Touchpoint cannot transition to :posted without both comment_url and posted_at; the changeset rejects partial transitions and the row stays at its prior state.

#### happy: Posted transition with comment_url and posted_at succeeds [67430a70]
Given Sam has a Touchpoint T in state :staged with polished_body set
When the agent calls update_touchpoint on T with state :posted, comment_url "https://www.reddit.com/r/elixir/comments/abc/_/xyz", and posted_at set to now
Then the response is {:ok, touchpoint}
And the Touchpoint state is :posted
And comment_url and posted_at are persisted

#### failure: Posted transition without comment_url is rejected; row stays staged [84205cbb]
Given Sam has a Touchpoint T in state :staged
When the agent calls update_touchpoint on T with state :posted but no comment_url
Then the response is {:error, changeset}
And the changeset has an error on :comment_url indicating it is required for the :posted state
And the Touchpoint state in the DB is still :staged
And no posted_at value is persisted on the row

### Transitioning a Touchpoint to :abandoned is non-destructive: angle, polished_body, comment_url, and posted_at all remain on the row.

#### happy: Abandoning a posted Touchpoint preserves angle, body, comment_url, and posted_at [46325a93]
Given Sam has a Touchpoint T in state :posted with angle "intro harness eng", polished_body "...", comment_url "https://...", posted_at last Tuesday
When the agent calls update_touchpoint on T with state :abandoned
Then the response is {:ok, touchpoint}
And the Touchpoint state is :abandoned
And the Touchpoint's angle, polished_body, comment_url, and posted_at fields are unchanged from before the transition
And the row remains queryable via list_touchpoints

### The LiveView "paste live URL" flow and the update_touchpoint MCP tool go through the same context function, producing identical persisted state across UI and agent surfaces.

#### happy: LiveView paste-URL flow and update_touchpoint MCP call leave identical persisted state [3924b7a5]
Given Sam has two identical Touchpoints T-ui and T-agent both in state :staged on the same thread with identical polished_body and angle
When Sam opens the LiveView for T-ui and pastes the live comment URL into the form, marking the touchpoint posted
And the agent in parallel calls update_touchpoint on T-agent with state :posted, comment_url (same URL), and posted_at (same timestamp)
Then T-ui and T-agent end in identical state in the DB: both :posted, both with the same comment_url and posted_at
And the same context function was invoked by both surfaces (verified by snapshotting the resulting Touchpoint rows and asserting field-equality)

### list_touchpoints(thread_id) returns every Touchpoint for the thread, ordered newest first by inserted_at, with full state and metadata per row.

#### happy: list_touchpoints returns all touchpoints newest-first with full metadata [d9536e67]
Given Sam has a thread T with three Touchpoints inserted in this order: T1 (:staged, angle "early take"), T2 (:abandoned, angle "decided against"), T3 (:posted, angle "intro harness eng", comment_url and posted_at set)
When the agent calls list_touchpoints(T.id)
Then the response is a list of three Touchpoints ordered T3, T2, T1 (newest inserted first)
And each Touchpoint in the response includes id, state, angle, polished_body, comment_url, posted_at, inserted_at
And T1's comment_url and posted_at are nil; T2's comment_url and posted_at are nil; T3's are populated

### Every Touchpoint operation (list, update, delete) is account-scoped; cross-account access returns :not_found and never leaks data.

#### happy: Account B cannot list, update, or delete Account A's Touchpoints [f634b7b2]
Given Account A has thread T-a with Touchpoint TP-a (state :staged)
And Account B has its own thread T-b with no Touchpoints
And Dave is signed in to Account B
When Dave's agent calls list_touchpoints(T-a.id)
Then the response is {:error, :not_found}
When Dave's agent calls update_touchpoint(TP-a.id, state: :posted, comment_url: "https://...", posted_at: now)
Then the response is {:error, :not_found}
And TP-a in the DB is unchanged
When Dave's agent calls delete_touchpoint(TP-a.id)
Then the response is {:error, :not_found}
And TP-a in the DB is unchanged (still exists, still :staged)

### Consumers of Touchpoint state read from the explicit state column directly, never inferring state from the presence of posted_at or comment_url.

#### happy: Engagement summary trusts the state column even when posted_at conflicts [626fe761]
Given a thread T has a Touchpoint TP with state :abandoned, posted_at set to last Tuesday, comment_url "https://www.reddit.com/..." set (because TP was previously :posted and was then transitioned to :abandoned per the abandon-preserves-fields rule)
When story 705's search response includes T as a candidate
Then T's engagement summary carries latest_state :abandoned
And NOT :posted (the consumer reads the state column directly and ignores posted_at presence)
And the same holds for any other consumer: if the column says :abandoned, that's the answer regardless of comment_url or posted_at presence

### delete_touchpoint(touchpoint_id) permanently removes a Touchpoint row from the database; the operation is account-scoped.

#### happy: delete_touchpoint removes the row; subsequent list does not include it [6eda3b2b]
Given Sam has a thread T with two Touchpoints TP-1 and TP-2
When the agent calls delete_touchpoint(TP-1.id)
Then the response is {:ok, touchpoint} carrying TP-1's pre-delete data
And the touchpoints table no longer contains a row with id TP-1.id
When the agent calls list_touchpoints(T.id)
Then the response is a list of one Touchpoint: TP-2
And TP-1 does not appear
