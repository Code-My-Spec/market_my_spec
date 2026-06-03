# Step 2 — Gather

Execute the Frame's saved searches against their sources (Upwork in v1) and persist a `JobPosting` row per result. Each posting also gets its embedding computed on insert (one OpenAI Embeddings API call per posting, the only model call MMS makes).

**Mode:** Tool action. No interview, no judgment — straight execution and triage of failures.

**Output:** JobPosting rows in the database (with `embedding` populated).

**Theory grounding:** `research/03_marketplace_signal_extraction.md` (signal-class hierarchy), `research/06_pipeline_anti_patterns.md` anti-pattern 1 (survivorship bias).

## The procedure

### 1. Run Gather

> Call `RunGather` with `{frame_id: <id>}`.

This is **per-saved-search**. If the Frame has 3 saved searches and none have been gathered yet, Gather runs all 3. If 2 of them already have JobPostings (from a probe round that was committed, or a prior Gather), only the third runs. Adding a new saved search to a committed Frame and re-running Gather only fetches the new one — additive, not idempotent-replacement.

### 2. Report the result

`RunGather` returns per-saved-search counts:

```
{
  "GoHighLevel agency sub-account migration": {gathered: 42, failed: 0},
  "GHL consolidation parent account":         {gathered: 18, failed: 2},
  "HubSpot to GoHighLevel migration":         {gathered: 31, failed: 1}
}
```

Read this back to the founder:

> "Gathered 91 postings across the 3 saved searches. 3 failed (likely transient — Upwork API timeouts or malformed records). Want me to retry the failures, or move on?"

If failures are <5% of the total, recommend moving on. If failures are >20%, something is off (rate limit, API down, query malformed) — pause and diagnose before continuing.

### 3. Inspect a few postings (optional but recommended)

Before clustering, the agent should spot-check that what came back actually matches the hypothesis. This catches "wrong query produced volume but wrong content" before wasting Cluster cycles.

> Call `ListCandidates` with `{frame_id: <id>}` — at this point Candidates don't exist yet, but the tool can return raw JobPostings if asked.

Or, more directly, the agent reads the first 5-10 postings from each saved search and asks itself:

- Do these describe the pain we hypothesized?
- Are the money signals present (`total_spent`, `hire_rate`)?
- Is the language matching what the founder said the market uses?

If a saved search produced 30 postings and the agent can tell from skimming that none of them are actually about the hypothesized pain — STOP. Go back to step 01_frame.md and revise that saved search. The Frame supports `UpdateFrame` for this; the corrupted saved search's postings can be discarded by removing the saved search before re-clustering.

## Watch for these failure modes

- **Survivorship bias** (anti-pattern 1) — Upwork shows people who *outsourced*. It does not show people who solved the problem in-house, hired an agency offline, or lived with it. The Board's "evidence of demand" is *demand among people who already chose to outsource*. Note this in the Frame's mental model — don't claim the Board represents total market demand.
- **Loud minority** (anti-pattern 3) — if one $400k client dominates a saved search's results, the entire downstream pipeline could be driven by one outlier buyer. Watch for this when reviewing aggregate spend stats; Cluster + Score will surface it as a per-Candidate outlier flag.
- **Wrong vocabulary** — if Gather returned volume but the postings aren't actually about the hypothesized pain, the saved search is wrong. Don't try to fix it in Cluster — fix it in Frame.

## What to skip

- Don't manually classify or score postings here. That's Score's job after Cluster.
- Don't try to "improve" the corpus by adding more searches mid-pipeline — finish a full pipeline run, then iterate. Otherwise you can't tell which signal came from which iteration.
- Don't sample for "interesting" postings to look at — KMeans + Cluster + Score will surface the relevant ones structurally. Manual cherry-picking biases what you see.

## Hand off to step 3

> "Got N JobPostings across the saved searches. Each has its embedding. Now I'll run Cluster — KMeans gives a seed partition, then we'll do the 3-pass pain-descriptor refinement to land the real semantic clustering."

Then load `steps/03_cluster.md`.
