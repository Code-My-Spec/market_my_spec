# No way to query "recent touchpoints on venue X" to manage profile-history risk

Filed 2026-05-24 from MMS MCP usage during the CodeMySpec marketing cycle. **Priority: low** — workflow safety, not a blocker.

## Problem

After staging multiple touchpoints on the same subreddit (or ElixirForum category) in a short window, the operator has to eyeball promotional-spam risk by gut. Reddit users and mods watch profile activity; a profile that drops 4 codemyspec.com links to r/ClaudeAI in 24 hours flags as promotional even if each comment is substantive.

Today's session staged 4 touchpoints (`40b4f8bf`, `2641ac95`, `898d3c7a`, `16b0d508`) across r/ClaudeAI (3) and r/vibecoding (1) with no way to surface the distribution before the next stage call. The agent had to track it manually in conversation context. Once context compacts or the session resets, the visibility is gone.

## Why it matters

1. **Cadence is a real signal.** Subreddit mods and engaged users notice when an account dumps multiple promoted links in a short window. Avoiding flags requires per-venue cadence awareness.
2. **Agent context is the wrong place to store it.** Cadence data persists across sessions; agent conversation context doesn't. Today's 4 touchpoints will be invisible to tomorrow's session unless the agent goes hunting.
3. **Profile-history risk grows non-linearly.** One link/day on a sub is fine; four links/day on the same sub is not. The orchestrator should make the count queryable, not leave it to the operator's recall.

## Proposed design

Extend `list_touchpoints` (or add a focused query tool) to accept venue + sub + time-window filters:

```
list_touchpoints(
  venue: "reddit",
  source_path: "r/ClaudeAI",
  since: "2026-05-23T00:00:00Z",
  state: ["staged", "posted"],
  limit: 20
)
```

Returns:

```
[
  {touchpoint_id, source_thread_id, state, staged_at, posted_at, polished_body_excerpt, comment_url},
  ...
]
```

## Acceptance criteria

1. `list_touchpoints` accepts optional `venue`, `source_path` (sub for Reddit, category for ElixirForum), `since`, `until`, `state` filters.
2. Default sort: `staged_at DESC`.
3. Response includes enough metadata for the operator to assess cadence: `posted_at`, `comment_url`, `polished_body` first 200 chars (so the operator can spot near-duplicate comments).
4. Docstring note: "Use this before staging another touchpoint on the same venue+sub within a short window to manage profile cadence. Suggested check: any venue+sub with 2+ posted touchpoints in the last 24h should pause for a day."

## Out of scope

- Automatic cadence enforcement (blocking `stage_response` when over a threshold). Too restrictive; some venues tolerate higher cadence than others. Leave the decision to the operator.
- Cross-venue cadence rules. Per-venue is enough for v1.
- Engagement metric overlay (upvotes, comment replies received). That's a separate enrichment.

## Reference

- Caller-side: today's session staged 4 touchpoints across 2 subs, agent tracked distribution manually in conversation context. Operator asked "want to keep going or call it for the day?" — that decision is exactly what this query would inform.
- Related: `content-asset-registry-and-thread-matching.md` (asset-id filter would let the operator also ask "how often am I linking to blog post X?").
