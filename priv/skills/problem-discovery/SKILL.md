---
name: problem-discovery
description: Take a fuzzy problem hypothesis through a 5-stage discovery pipeline (Frame → Gather → Cluster → Score → Red-team → Board) over real money-validated job postings, producing a board where every row is killable in one click. Use when the founder wants to "validate a problem", "find what to build", "run problem discovery", "test a hypothesis with real demand", or has a hunch about a market and wants to check whether money is already moving. The conviction comes from money already moving, not from an LLM narrating cleanly.
user-invocable: true
argument-hint: [optional hypothesis seed, e.g. "vendor onboarding pain" or "GoHighLevel migration"]
---

# Problem Discovery

You are guiding a solo founder through validating a fuzzy problem hypothesis against money-validated job posting data. The pipeline runs in five sequenced stages (Frame → Gather → Cluster → Score → Red-team) and produces a Board where every row is killable in one click.

**The core principle:** Money already moving is the only validation signal worth gating on. Surveys, interviews, upvotes, and HN comments are *inputs to Frame*, not validation. Reality decides. (See `research/01_money_as_validation.md` for the practitioner literature.)

**Your role:** You do all the model work. MMS is the harness — it runs the algorithmic stages (KMeans clustering, money-gate evaluation, persistence) and exposes MCP tools you invoke. The skill walks you through which tool to call at which phase and how to think about the work. You write the pain descriptors, you make the kill arguments, you decide merge/split.

## How to run this skill

**Progressive disclosure.** The 6 phase steps each live in `steps/NN_*.md`. Practitioner research grounding each phase lives in `research/*.md`. Do **not** read them all upfront. Orient first, then load one step at a time as you enter each phase; load research files when you want deeper grounding for a specific stage.

```
skills/problem-discovery/
├── SKILL.md              ← you are here
├── steps/
│   ├── 01_frame.md       ← compose the hypothesis + thresholds + kill_condition
│   ├── 02_gather.md      ← fetch JobPostings per saved search
│   ├── 03_cluster.md     ← KMeans seed + 3-pass agent refinement
│   ├── 04_score.md       ← apply money gate, classify PaidJobSignals
│   ├── 05_redteam.md     ← prosecute each Candidate per Klein pre-mortem
│   └── 06_board.md       ← assemble the killable-in-one-click view
└── research/
    ├── 00_index.md       ← what's in here
    ├── 01_money_as_validation.md
    ├── 02_framing_fuzzy_problems.md
    ├── 03_marketplace_signal_extraction.md
    ├── 04_clustering_qualitative_records.md
    ├── 05_red_teaming_candidates.md
    ├── 06_pipeline_anti_patterns.md
    └── 99_design_critique.md
```

## Step 0 — Orient

Before touching anything, do these in parallel:

1. Check whether any Frames already exist on this account via `list_frames`. If one matches the user's hypothesis seed, this is **iteration mode** (see bottom).
2. Skim the user's argument (hypothesis seed) if given. If it's vague ("vendor pain"), good — that's what Frame is for. If it's already specific ("Salesforce-to-GoHighLevel migration for agencies with 20+ sub-accounts"), even better — Frame will sharpen it further.
3. If the user gave nothing, ask in one sentence: "What problem do you suspect is real? Hunch, headline, or one-liner is fine — we'll sharpen it in Frame."

Greet the user briefly, confirm the seed (or get one), and confirm they want to run the full 5-phase flow or jump to a specific phase (most start at Frame).

## The 5 phases

| # | Phase | Mode | Primary tools | Output |
|---|---|---|---|---|
| 1 | Frame | Iterative interview + probe-mode Gather | `ListFrames`, `CreateFrame`, `UpdateFrame`, `GetFrame`, `RunGather` (probe) | Frame artifact (description + saved searches + money_gate + kill_condition) |
| 2 | Gather | Per-saved-search execution | `RunGather` | JobPosting rows (one per result, with embeddings) |
| 3 | Cluster | KMeans seed + 3-pass agent refinement | `RunCluster`, `ListCandidates`, `ListPostingsForCandidate`, `SetPainDescriptor`, `MergeCandidates`, `SplitCandidate`, `LabelCandidate` | Candidates (groups of JobPostings, semantically labeled) |
| 4 | Score | Apply money gate, classify | `RunScore`, `ListPostingsForCandidate` | PaidJobSignal classifications + Candidate aggregated scores |
| 5 | Red-team | Per-Candidate conversational prosecution | `RedTeamCandidate`, `ListCandidates` | RedTeamVerdict per Candidate (overwrites Score's verdict) |
| 6 | Board | Assemble + hand off to founder | `GetBoard` | Killable-in-one-click table + kill_condition status |

For each phase:

1. Read `steps/NN_*.md` when you reach it — not before.
2. Optionally read the referenced research file(s) for deeper grounding when the founder asks "why?" or you're uncertain about a judgment call.
3. Follow the procedure in the step doc — invoke the tools it names, make the judgments it asks for.
4. Between phases, give the user a one-sentence transition: what's done, what's next.

## Operating principles

- **Money already moving > everything else.** Strong KEEP requires the money gate to have cleared. Interviews and surveys are Frame inputs only. (`research/01_money_as_validation.md`.)
- **Use the market's vocabulary, not yours.** Frame's Sales-Safari vocabulary audit grounds queries in observed language. If the market calls it "workflow rebuild" and you frame it as "automation migration," Gather will miss signal. (`research/02_framing_fuzzy_problems.md`.)
- **Describe pain per record before grouping.** The 3-pass cluster refinement (pain descriptor → consolidate/split → name) prevents the model from inventing categories from its training distribution. Name clusters AFTER they form, not before. (`research/04_clustering_qualitative_records.md`.)
- **Prosecute, don't balance.** Red-team is adversarial. Past-tense grammar ("this bet has already failed — what went wrong?") activates specific recall better than "what could go wrong?" (`research/05_red_teaming_candidates.md`.)
- **One Candidate at a time during Red-team.** Conversational prosecution. The founder is in the loop on top candidates. Not a batch operation.
- **The Board is a Type 2 decision per row.** KEEP/WATCH/KILL means "run the next experiment / wait for more signal / drop." It doesn't mean "build the product." (`research/05_red_teaming_candidates.md` on Bezos two-door framework.)
- **Watch for the six anti-patterns.** Survivorship bias, narrative-driven sampling, loud minority, confirmation loop, validation theater, services-vs-product. Each phase step calls out the relevant ones. (`research/06_pipeline_anti_patterns.md`.)
- **Write artifacts as you go.** Each phase mutates persistent state via MCP tools. The pipeline supports rerunning any phase from upstream artifacts — tightening the money gate doesn't re-pay for the corpus.

## Iteration mode

If the user already has a Frame for this hypothesis:

1. `list_frames` → find the existing Frame by description match
2. `get_frame` → load its current state (description, saved searches, money_gate, kill_condition, stage artifact counts)
3. Ask: "What's the change you want to make? Tightening the threshold? Adding a source? Re-clustering? Re-Red-teaming after revising the kill argument?"
4. Branch into the relevant phase step (e.g., revising the threshold → step 04_score.md; adding a source → step 02_gather.md). The pipeline's per-stage rerun semantics mean you only redo the affected work.

Common iteration patterns:
- **"The Board looks thin"** → check `research/99_design_critique.md` for the "thin corpus" warning; consider adding saved searches (back to Frame + Gather) before retuning anything.
- **"This Candidate looks weird"** → 03_cluster.md's 3-pass refinement; agent inspects, may merge or split.
- **"I want to raise the bar"** → 04_score.md; update Frame's money_gate, RunScore reclassifies in place.

## Surface map: founder-direct LiveView vs skill-driven agent flow

Problem discovery exposes two parallel surfaces against the same Frame artifact:

- **Founder-direct LiveView surfaces.** The founder lands on `/problem-discovery/frames` (list view) and `/problem-discovery/frames/:id` (Frame detail with the inline Board, the empty-Gather notice, and the one-click KILL button). These surfaces let the founder trigger Gather / Cluster / Score directly and override any Candidate's verdict with a single click. No agent is required to read the Board or kill a row.
- **Skill-driven agent flows.** This skill walks the agent through the same five phases via the ProblemDiscovery MCP tools (CreateFrame, RunGather, RunCluster, RunScore, RedTeamCandidate, GetBoard, plus the labeling tools SetPainDescriptor, MergeCandidates, SplitCandidate, LabelCandidate). The agent's job is the model work — descriptors, semantic labels, prosecution — that the LiveView surfaces cannot do mechanically.

Both surfaces read and write the same DB artifacts; the LiveView and the agent flow stay coherent because every state mutation goes through `MarketMySpec.ProblemDiscovery` context callbacks.

## What this skill does NOT do

- Validate that a problem is *productizable* — that's the Red-team's job (KEEP-PRODUCTIZABLE vs KEEP-SERVICE-ONLY split per `research/06_pipeline_anti_patterns.md` anti-pattern 6)
- Build the thing or write code — the Board is a list of validated problems, not a product spec
- Replace customer interviews — Board KEEP rows are leads to interview, not answers to "should I build this"
- Predict revenue or market size — the Board says "money is moving here," not "you will earn $X"
- Auto-refresh — the founder/agent triggers Gather, Cluster, Score, Red-team explicitly via MCP tools

The goal is a compact, evidence-backed Board the founder can take into customer conversations starting tomorrow morning, with kill arguments already prosecuted so the conversations can be specific.
