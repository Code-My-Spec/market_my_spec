# Step 6 — Board

Assemble the final view: every Candidate with its post-Red-team verdict, kill argument, cheapest-kill-test, and corpus-health header. The founder scans the Board, kills what they don't believe, and walks away with a short list of leads to take into customer interviews.

**Mode:** Tool fetch + present + hand-off. The founder owns the kill/keep/watch decisions from here.

**Output:** The Board view, rendered for the founder. No new persisted artifacts (RedTeamVerdicts already exist from step 5; the Board is a projection).

**Theory grounding:** `research/99_design_critique.md` (the assembled critique), `research/06_pipeline_anti_patterns.md` anti-pattern 5 (validation theater — the corpus-health header is the structural fix).

## The procedure

### 1. Fetch the Board

> Call `GetBoard` with `{frame_id: <id>}`.

Returns the assembled projection:

```
{
  frame: {
    description: "...",
    money_gate: {total_spent_min: $5000, hire_rate_min: 50%},
    kill_condition: {min_money_gated_candidates: 3}
  },
  corpus_health: {
    total_postings: 91,
    postings_with_client_stats: 91,
    postings_gated_in: 16,
    distinct_clients_in_keep_tier: 7
  },
  kill_condition_status: :met,  // or :not_met
  candidates: [
    {
      label: "Post-acquisition GHL sub-account consolidation",
      score: 8,
      verdict: :keep_productizable,
      kill_argument: "...",
      cheapest_kill_test: "Call 2 of the top spenders; if both say 'a tool wouldn't help because every consolidation is different,' kill",
      gated_in_count: 8,
      distinct_clients: 5
    },
    ...
  ]
}
```

### 2. Read the corpus-health header to the founder FIRST

Before any Candidates, surface the corpus health. This is the structural guard against validation theater.

> "Quick corpus check before the Candidates:
> - 91 postings gathered across 3 saved searches
> - 16 cleared the money gate (~18%)
> - 7 distinct clients in the KEEP tier
> - kill_condition was 'at least 3 money-gated Candidates' — met (we have 3 with score ≥ 3)"

**If `total_postings < 50` or `distinct_clients_in_keep_tier < 5`**, lead with a warning:

> "⚠️ Thin corpus warning. Only N postings, M distinct strong clients. Treat all verdicts below as Frame input for the next iteration, not validation. Recommend: add more saved searches or relax thresholds before drawing conclusions."

This is non-negotiable per `research/06_pipeline_anti_patterns.md` anti-pattern 5. A Board that looks confident over thin data is the most dangerous artifact this pipeline can produce.

**If `kill_condition_status == :not_met`**, lead with that:

> "The Frame's kill_condition required at least N money-gated Candidates. We got M. This is a NO on the hypothesis. The Candidates below are visible for your awareness but the pre-committed bar was not cleared."

Don't soften this. The kill_condition was the founder's pre-commitment; honoring it is the discipline that makes the pipeline trustworthy.

### 3. Present the Candidates by verdict

Group rows by verdict so the founder sees the strongest signal first:

**KEEP-PRODUCTIZABLE** (the productizable bets — most actionable)

For each row, surface:
- Label (the descriptor-grounded name)
- Score / gated-in count
- Distinct clients
- Kill argument (1-2 sentences)
- Cheapest kill test (the experiment that resolves it)

**KEEP-SERVICE-ONLY** (real demand, but it's a services lead, not a product lead)

Same columns. Explicitly flag: "This is a strong services opportunity. If you want a product, the cheapest_kill_test is what would prove someone wants software instead of a freelancer."

**WATCH** (signal is there but thin or concentrated)

Same columns, with the WATCH reason called out: "Concentration: 5 of 6 signals from 1 client" or "Recent only: all 4 signals from last 90 days, may be a trend not a market" or similar.

**KILL** (the kill argument survived — devil's advocate won)

Show these too, briefly. The kill arguments here are documentation of what was considered and rejected. If a future iteration tightens or relaxes the Frame, these are the things to re-evaluate.

### 4. The killable-in-one-click affordance

Each row on the Board has a kill button (in the LiveView UI, story 739). The agent doesn't kill rows directly — the founder does that from the UI. The agent's job here is to make sure each row has a clear enough kill argument that the founder can decide in seconds.

If a row's kill_argument is generic or hedging, that's a signal the Red-team pass on that Candidate was weak. Offer to re-Red-team it:

> "The kill argument for [Candidate] reads as a generic hedge. Want me to re-prosecute it with stronger evidence focus?"

### 5. Hand off to the founder

The Board is the deliverable. The founder takes the KEEP-PRODUCTIZABLE rows into customer conversations starting tomorrow morning — they have kill arguments already prosecuted so conversations can be specific ("Tell me about the last time you did this work — when was it, what was the worst part, what would you have paid to skip?").

A reasonable closing:

> "That's the Board. Three KEEP-PRODUCTIZABLE rows, one KEEP-SERVICE-ONLY, two WATCH, four KILL. The cheapest_kill_tests on the top KEEPs are all customer calls — start with [Candidate label] since it has the most distinct clients (5) and the most concrete kill_argument. Want me to write a short outreach script for those clients, or hand off here?"

## What this skill does NOT promise from the Board

- It does not promise the KEEP rows are a market. They are demand signals among Upwork outsourcers — a population that excludes in-house solvers, agency clients, and people who lived with the pain. (Anti-pattern 1, survivorship bias.)
- It does not promise the KEEP rows would buy software. The KEEP-PRODUCTIZABLE split is best-judgment, not validation. Only customer conversations validate productizability. (Anti-pattern 6.)
- It does not promise the Board reflects current demand. The postings may be 6-18 months old. Check posting dates per Candidate; if everything is stale, the trend may already be over.

## Iteration from the Board

If the founder isn't satisfied with the Board:

- **Wants more signal** → back to step 01 (Frame) to add saved searches; re-run from Gather forward
- **Wants tighter signal** → step 04 (Score) with a higher `money_gate`
- **A Candidate looks wrong** → step 03 (Cluster) to merge/split or re-label
- **A verdict feels wrong** → step 05 (Red-team) to re-prosecute that single Candidate

The pipeline supports surgical reruns. Tightening the threshold doesn't re-pay for the corpus. Adding a saved search doesn't re-fetch the others.

## End of the skill flow

The Board is the deliverable, not a milestone toward another artifact. The founder leaves the skill with:

1. A short list of KEEP-PRODUCTIZABLE Candidates with kill arguments and cheapest tests
2. A short list of KEEP-SERVICE-ONLY for if they want a services play
3. Honest WATCH/KILL rows showing what was considered and dropped
4. A documented Frame they can return to and iterate on

The conviction comes from money already moving, not from an LLM narrating cleanly. The Board is the structured output of that conviction.
