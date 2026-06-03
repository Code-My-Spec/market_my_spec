# Step 4 — Score

Apply the Frame's `money_gate` to every JobPosting. Each posting gets a `PaidJobSignal` record classified `gated_in` or `gated_out` based on its `total_spent` and `hire_rate` against the threshold. Each Candidate's aggregated score is recomputed from the count and quality of its `gated_in` member signals.

**Mode:** Tool action + optional threshold-tuning iteration.

**Output:** PaidJobSignal classifications + Candidate.score values.

**Theory grounding:** `research/01_money_as_validation.md` (money-gate hierarchy: paid > clicks > says).

## The procedure

### 1. Run Score

> Call `RunScore` with `{frame_id: <id>}`.

This:
- Reads the Frame's `money_gate` (e.g., `total_spent_min: $5,000`, `hire_rate_min: 50%`)
- For each JobPosting in the Frame, creates or updates a `PaidJobSignal` with `classification: :gated_in | :gated_out`
- Recomputes each Candidate's aggregated score from its `gated_in` member signals
- Makes zero HTTP calls to the corpus source — pure database work

Returns per-Candidate counts:

```
{
  "Post-acquisition GHL sub-account consolidation": {gated_in: 8, gated_out: 15, score: 8},
  "HubSpot → GoHighLevel contact-history migration": {gated_in: 3, gated_out: 12, score: 3},
  ...
}
```

### 2. Read the gated_in counts back to the founder

> "Score is in. Of the N total postings, X cleared the money gate. Three Candidates have meaningful signal:
> - [Candidate label A]: 8 gated-in / 23 total
> - [Candidate label B]: 5 gated-in / 19 total
> - [Candidate label C]: 3 gated-in / 12 total
>
> The other M Candidates dropped to gated_in count ≤ 1 — those are likely noise unless one of them is the surprise the founder wanted to see."

### 3. Threshold-tuning iteration (only if explicitly requested)

If the founder says "the bar feels too high — I'm losing real demand" or "the bar feels too low — too much noise getting in," they can tighten or relax. This is one of the cheapest operations in the pipeline:

> Call `UpdateFrame` with the new `money_gate` values.
> Call `RunScore` again.

The PaidJobSignal classifications update in place — no records are deleted or refetched. Each posting's classification field is rewritten; the count of records stays the same, only the classifications change. Candidate scores recompute. (This is rule 8 of story 743, and the failure mode is anti-pattern 5 of `research/06_pipeline_anti_patterns.md`: don't tune the threshold to make the Board look better. Tune for honest signal.)

**Push back on threshold-shopping.** If the founder is on round 3 of "let's try lowering it a bit more to see if more rows clear," they're probably rationalizing toward a YES. The threshold the Frame committed to was their pre-decision judgment. Honor it unless they have a specific reason it was wrong (e.g., "I didn't realize Upwork's `total_spent` is lifetime, not last-12-months" — that's a real recalibration; "I want to see more KEEP rows" is not).

### 4. Inspect the high-signal Candidates

For the top 3-5 Candidates by `gated_in` count, call `ListPaidJobSignals` for each:

> Call `ListPaidJobSignals` with `{candidate_id: <id>, filter: :gated_in}`.

Read the gated_in postings. Look for:

- **Concentration risk** (anti-pattern 3) — is one client driving most of the signal? If 6 of 8 gated_in signals are from the same Upwork client, that's not 6 data points — that's one client posting 6 jobs. Note this concentration; the Red-team will need to address it.
- **Quality of the postings** — are these substantive postings with detail, or one-liners? One-liner postings often indicate the client is shopping cheap, regardless of their lifetime spend.
- **Description-pain alignment** — re-read the posting against its Candidate's label. Does this gated_in signal really represent the labeled pain? If not, the Cluster pass missed (back to step 03_cluster.md for that Candidate).

### 5. Hand off the surviving Candidates to Red-team

Any Candidate with `score >= 3` (3+ gated_in signals) is a Red-team candidate. Lower-scored Candidates don't go to Red-team — they're not strong enough to justify prosecution.

Report to the founder:

> "Three Candidates have enough money-gated signal to red-team. Two have 1-2 signals and we'll WATCH them. The other N have 0-1 gated-in and won't make it to the Board as KEEP."

## Watch for these failure modes

- **Threshold shopping** (anti-pattern 5, validation theater) — the bar is what the Frame committed to. Rationalizing the bar down to make the Board look better is the exact failure mode the kill_condition was designed to prevent.
- **services-vs-product** (anti-pattern 6) — Score's money_gate only proves these clients are paying *humans* for the work. It does NOT prove they would pay for *software* that does it. The KEEP-PRODUCTIZABLE vs KEEP-SERVICE-ONLY split happens in Red-team — Score's signal is necessary but not sufficient.
- **Loud minority** (anti-pattern 3) — one whale client posting repeatedly can dominate a Candidate's signal. The Red-team should consider whether the demand is broad or concentrated.

## Hand off to step 5

> "Three Candidates cleared the money gate with enough signal to prosecute. Now we run Red-team — one Candidate at a time, conversational, past-tense framing. The founder is in the loop on the top candidates."

Then load `steps/05_redteam.md`.
