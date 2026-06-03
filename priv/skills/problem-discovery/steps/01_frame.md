# Step 1 — Frame

Turn the founder's fuzzy hypothesis into a committed Frame artifact: description, list of saved searches (source + query), money_gate threshold, and kill_condition. This is the only phase where the founder's judgment defines the bar for "real."

**Mode:** Iterative interview + probe-mode Gather rounds. Multi-turn — do not try to land a committed Frame in one pass.

**Output artifact:** Frame (persisted via `CreateFrame` after probe-and-revise rounds).

**Theory grounding:** `research/02_framing_fuzzy_problems.md` (Blank's falsifiable hypotheses, Moesta's switch-event framing, Fitzpatrick's kill condition), `research/01_money_as_validation.md` (the money-gate hierarchy).

## What a Frame contains

```
Frame {
  description       — 1-3 sentence hypothesis statement (the customer segment + the
                      pain + the triggering event)
  saved_searches    — list of {source: :upwork, query: "..."} pairs
  money_gate        — {total_spent_min: $X, hire_rate_min: Y%}
  kill_condition    — {min_money_gated_candidates: N}
}
```

Every field is the founder's judgment. The model doesn't pick the threshold. The model doesn't write the kill_condition.

## The procedure

### 1. Sales-Safari vocabulary audit (first turn)

Before any tool call, get the founder talking about who actually has this pain and what they call it.

Two questions:

> "Who specifically has this pain? Not 'small businesses' — give me a role, a company size, a triggering context."

> "When you've heard this pain in the wild — on Reddit, in Upwork posts, in customer interviews, in your DMs — what words do people use for it?"

This is Amy Hoy's Sales Safari technique: observe people in their natural watering holes, capture their vocabulary, then encode that vocabulary into the Gather queries. Founder-invented vocabulary misses signal. Market vocabulary catches it.

If the founder has nothing — no observed examples, no captured language — pause. Frame requires at least *some* prior observation. Suggest they spend an hour reading r/<their domain> or skimming Upwork manually before proceeding. Don't go further into the pipeline on pure speculation; that produces validation theater (`research/06_pipeline_anti_patterns.md` anti-pattern 5).

### 2. Triggering event (Moesta switch interview)

> "What event causes someone to start looking for a solution? Not 'they realize they have CRM pain' — what specifically just happened in their life?"

Examples:
- Bad: "Agencies have CRM pain"
- Good: "Agency just acquired another agency and inherited 47 GoHighLevel sub-accounts they need to merge into one parent account"

The switch event is what separates latent pain from active demand. Job postings describing the switch event are the highest-value rows downstream.

### 3. Draft saved searches (one per framing)

Per `research/06_pipeline_anti_patterns.md` anti-pattern 2 (narrative-driven sampling): **always draft at least 3 saved searches with semantically distinct framings.** If only one framing produces signal, that framing is the hypothesis, not the reality.

Draft them in conversation with the founder. Use their vocabulary (from step 1). Each saved search is `{source: :upwork, query: "..."}`.

Example for a "GoHighLevel migration" hypothesis:
- `{:upwork, "GoHighLevel agency sub-account migration"}`
- `{:upwork, "GHL consolidation parent account"}`
- `{:upwork, "marketing automation migration HubSpot to GoHighLevel"}`

### 4. Probe-mode Gather (validate the saved searches BEFORE committing)

For each draft saved search, run `RunGather` in probe mode (small sample, no persistence):

> Call `RunGather` with `{frame: <draft uncommitted Frame>, mode: :probe, limit: 20}`

This returns a sample of postings without persisting a Frame. The agent reviews the sample for:

- **Relevance**: do these postings actually describe the hypothesized pain, or did the query catch unrelated work?
- **Volume**: did the source return enough? If <5 results per query consistently, the query is too narrow.
- **Money signals**: do the returned postings have `total_spent` values? If everything is $0 or low, the corpus may be all tire-kickers regardless of threshold.

If a saved search returns garbage, revise the query and probe again. **This is the iterative loop** — expect 2-5 rounds before the saved searches feel right.

### 5. Money gate (founder sets the bar)

> "What's the threshold for 'this client is for real'? They've spent at least $X on the platform, and at least Y% of their job posts ended in a hire."

Defaults to suggest if the founder is stuck:
- `total_spent_min: $5,000` — separates demonstrated buyers from one-time experimenters
- `hire_rate_min: 50%` — separates committed clients from window-shoppers

But these are *suggestions*. The founder owns the bar. If they say "no, I only care about $50k+ clients who hire 80% of the time," that's the rule. Score will apply exactly what the Frame says.

### 6. Kill condition (the falsifiable pre-commitment)

> "If, after this pipeline runs, we see fewer than N money-gated Candidates — that's a NO. What's N?"

Blank's falsifiable hypothesis principle: a hypothesis without a kill condition is a wishlist. Force the founder to commit to a number they'll honor.

Sensible defaults: `min_money_gated_candidates: 3`. If even three problem clusters can't muster money-gated demand, the hypothesis has failed its own gate.

### 7. Commit the Frame

Once probe rounds have validated the saved searches and the thresholds are set:

> Call `CreateFrame` with `{description, saved_searches, money_gate, kill_condition}`.

The Frame artifact persists. Hand off to step 02.

## Watch for these failure modes

- **Founder-invented vocabulary** (anti-pattern 4, confirmation loop) — if the queries use words the market doesn't, Gather returns confirmation-shaped noise. Push back on every query that doesn't quote actual observed language.
- **One framing only** (anti-pattern 2, narrative-driven sampling) — refuse to commit a Frame with fewer than 3 saved searches in distinct framings. Volume across framings is the cross-check.
- **Surveys / interviews / upvotes as evidence** — these are Frame inputs (vocabulary, hypotheses), not validation. Don't let the founder rationalize a Frame because "20 people on Reddit said they have this pain." Reddit doesn't pay anyone.

## Hand off to step 2

> "Got the Frame committed with N saved searches. Now I'll run Gather to fetch JobPostings from each source — it's per-saved-search and additive, so adding sources later only fetches the new ones."

Then load `steps/02_gather.md`.
