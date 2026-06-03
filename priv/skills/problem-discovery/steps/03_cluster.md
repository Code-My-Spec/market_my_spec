# Step 3 — Cluster

Group JobPostings into Candidates (problem clusters) via a two-pass process:
1. **MMS runs KMeans** over JobPosting embeddings to produce a deterministic seed partition.
2. **Agent runs the 3-pass refinement** (describe pain → consolidate/split → name) to land the actual semantic clustering.

**Mode:** Tool action (pass 1) + structured agent work + interview-with-founder (pass 2).

**Output:** Candidates persisted with labels and centroids; each JobPosting carries a `pain_descriptor`.

**Theory grounding:** `research/04_clustering_qualitative_records.md` (grounded theory, KJ method, "name after group"), `research/06_pipeline_anti_patterns.md` anti-patterns 2 & 4 (sampling and confirmation).

## Why two passes (and not just KMeans, and not just the agent)

KMeans on embeddings groups postings by *text-surface similarity*. Two postings mentioning "vendor onboarding" but about different pains (UX vs compliance) end up in the same cluster because they share terminology. That's the KMeans failure mode.

The agent-only failure mode (per `research/04_clustering_qualitative_records.md`): give an LLM 200 postings and ask "produce 5 categories," and it invents categories from its training distribution rather than discovering them from the data. Confident, fluent, often wrong.

The fix: KMeans gives a deterministic seed partition the agent reshapes through the 3-pass grounded-theory refinement. KMeans does the volume work; the agent does the semantic judgment.

## Pass 1 — Run KMeans

> Call `RunCluster` with `{frame_id: <id>}`.

This:
- Reads all JobPosting embeddings for the Frame
- Auto-selects K via silhouette over K ∈ {3..8}
- Runs `Scholar.Cluster.KMeans.fit/2` with a deterministic seed
- Persists Candidates with centroids (mean of member embeddings)

Returns the Candidate set. Each Candidate has:
- A mechanical centroid (you don't reason about it, but pgvector uses it for cross-rerun ID stability)
- A list of member JobPostings
- No label yet
- A score field that's not yet meaningful (Score runs in step 4)

> Call `ListCandidates` with `{frame_id: <id>}` to inspect what came back.

You'll see N Candidates, each with a member count. Don't react to them yet — they're a seed, not the answer.

## Pass 2.1 — Describe pain per JobPosting (open coding)

For each JobPosting in each Candidate, write a structured 1-line pain descriptor in the *posting's own language*. Goal: ≤10 words, capture the underlying frustration the client is hiring to resolve.

> For each posting, call `SetPainDescriptor` with `{job_posting_id: <id>, pain_descriptor: "..."}`.

Examples:
- ✅ "Merging duplicate GHL sub-accounts after agency acquisition"
- ✅ "Migrating contact history from HubSpot to GoHighLevel"
- ✅ "Automating intake form sync between sales and ops"
- ❌ "CRM stuff" (too vague — won't differentiate from anything)
- ❌ "Client needs help" (just paraphrases that they posted a job)
- ❌ "Marketing automation modernization" (your words, not theirs — defeats the purpose)

**Do this per posting, not per cluster.** That's the discipline the literature insists on: open coding before axial grouping. If you describe at the cluster level, you're already grouping — you've skipped pass 2.1 and gone straight to pass 2.3 with predetermined categories. (`research/04_clustering_qualitative_records.md` grounded theory rule.)

For 100 postings this is 100 tool calls. They're cheap individually; the time investment is in your reading. Skim the title + description, write 1 line, move on. Don't agonize.

## Pass 2.2 — Consolidate or split (axial coding)

Now look at the pain descriptors *within each Candidate*. Ask:

- **If descriptors within a Candidate are wildly different** → the KMeans cluster grouped postings by shared vocabulary, not shared pain. Split. Call `SplitCandidate` with a partition spec.
- **If two Candidates have nearly identical descriptors** → KMeans split what should have stayed together. Merge. Call `MergeCandidates` with the candidate ids to combine.
- **If descriptors are coherent** → leave the Candidate alone.

This is where the founder comes back into the loop. For the top 3-5 most populous Candidates, summarize the descriptors to the founder:

> "Candidate 1 has 23 postings, and the pain descriptors look like this: [paste 5 representative ones]. Does this feel like one coherent problem to you, or are you seeing two distinct things in there?"

If the founder says "those are two different things," `SplitCandidate`. If they say "yeah, that's the same as Candidate 4," `MergeCandidates`.

This is the only pipeline phase where the founder is in the loop on judgment. Their domain knowledge is the highest-quality calibration we have.

## Pass 2.3 — Name (selective coding, name AFTER grouping)

For each final Candidate, write a label *grounded in the pain descriptors*. The label should be specific enough that the founder, reading the Board, knows exactly which problem cluster this row represents.

> For each Candidate, call `LabelCandidate` with `{candidate_id: <id>, label: "..."}`.

Examples:
- ✅ "Post-acquisition GHL sub-account consolidation"
- ✅ "HubSpot → GoHighLevel contact-history migration"
- ❌ "Migration cluster" (too generic)
- ❌ "Cluster 1" (default fallback — never accept this)

**The name comes last.** If you wrote names in pass 2.1 or 2.2, you contaminated the grouping. The KJ-method discipline: cards into piles by affinity, name the piles after the sorting is done.

## When to re-run RunCluster

If after pass 2 you realize the KMeans seed was so off that splitting/merging would take forever, you can `RunCluster` again with a different K (auto-selection will try a different value, or you can hint). The previous Candidates are overwritten — they have no history. Any RedTeamVerdicts attached to overwritten Candidates are lost (overwrite semantics).

In practice: trust the seed unless it's obviously catastrophic. Manual refinement is faster than re-clustering and gives the agent better context.

## Watch for these failure modes

- **Naming before grouping** — the LLM monoculture trap. If you find yourself thinking "this is the X cluster" while writing pain descriptors, stop and force yourself to write the descriptor without naming. The name comes in pass 2.3.
- **Confirmation loop** (anti-pattern 4) — if you wrote the descriptors knowing what the Frame hypothesis was, you may have unconsciously fitted descriptors to confirm the Frame. Cross-check: do any descriptors describe pain *adjacent* to the hypothesis that surprised you? If everything is exactly on-thesis, you may be confirming.
- **Vague descriptors** — "CRM stuff" doesn't differentiate. Pain descriptors that don't differentiate Candidates from each other are useless. Push for specifics.

## Hand off to step 4

> "Candidates are clustered and labeled by pain. Now Score applies the Frame's money gate to each JobPosting — that classifies the PaidJobSignals as gated_in or gated_out, and each Candidate's aggregated score reflects only its gated_in members."

Then load `steps/04_score.md`.
