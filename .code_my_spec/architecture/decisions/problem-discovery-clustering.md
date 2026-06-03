# Problem-Discovery Clustering Architecture

## Status
Accepted

## Context
The problem-discovery feature (stories 739–743) runs a 5-stage pipeline — Frame → Gather → Cluster → Score → Red-team → Board — that takes a founder's fuzzy hypothesis and produces a board of money-validated problem candidates ready for kill/keep decisions.

The Cluster stage is the load-bearing decision for everything downstream. Cluster groups raw `JobPosting` records into `Candidate` (problem clusters); Score then evaluates per-`JobPosting` money signals (`PaidJobSignal`) and aggregates into a per-`Candidate` score; Red-team prosecutes each surviving Candidate.

A guiding constraint sets the design space:

> "I want this to be a harness an LLM uses, not an application that uses LLMs, at least for the moment."

MMS itself should not be calling large language models for narrative work. The agent (Claude Code, via MCP) is the LLM-bearing party; MMS is the persistence and orchestration layer.

This constraint plus the Three Amigos rules (stable Candidate identity across reruns so RedTeamVerdicts persist; deterministic-enough reruns; "overwrite, no versioning" semantics) define the clustering architecture.

### Options considered

**Path A — Agent-driven clustering (pure harness).** The agent reads JobPostings via MCP, decides on clusters, writes Candidates back via a tool call.
- Pro: Maximally honors the harness principle. No embedding model, no clustering algorithm in MMS.
- Con: **Non-deterministic.** Re-running clustering produces different groupings, which means Candidate IDs reset, which means RedTeamVerdict's `belongs_to Candidate` becomes a foot-gun — verdicts go stale silently when re-clustering shifts membership.
- Con: "Rerun Cluster" becomes a multi-turn conversation rather than a sub-second operation.

**Path B — Algorithmic clustering only (embeddings + HDBSCAN/KMeans, MMS owns the whole stage).** MMS computes embeddings, runs clustering, produces Candidates deterministically. Agent kicks it off.
- Pro: Stable Candidate IDs, sub-second reruns, verdict persistence is tractable.
- Con: MMS is making model calls (even if just embeddings — still an LLM-class dependency).
- Con: No semantic labeling — cluster names are mechanical ("Cluster 1", "Cluster 2") unless an additional labeling pass is added.

**Path C — Hybrid: algorithmic grouping + agent-driven labeling and refinement.** MMS does deterministic embedding + clustering for stable cluster identity and membership. The agent reviews the clusters, provides semantic names, and can submit merges or splits via MCP tools.
- Pro: Stable identity (algorithmic centroids match across reruns), semantic labels and refinement (agent provides them).
- Pro: Embedding dependency is the only ML/LLM call MMS owns; everything semantic happens in the agent's existing context (Claude usage, not MMS's bill).
- Con: Two systems to keep coherent — MMS owns membership, agent owns labels. Merge/split tool surface adds API design work.

### Why C wins

- **Candidate ID stability is the decision that drags everything else.** RedTeamVerdict belongs_to Candidate, and Sam needs verdicts to persist when he tweaks the Frame and reruns Score (rule 5) or adds saved searches and re-Gathers (rule 3). Only an algorithmic clustering stage can produce stable IDs without elaborate matching heuristics.
- **The harness principle is mostly preserved.** The only model call MMS makes is the embedding pass on Gather. All semantic work (naming clusters, deciding splits/merges, prosecuting verdicts) happens in the agent.
- **Sub-second reruns are achievable.** Embeddings persist on JobPosting (embed-once on Gather, never re-embed); clustering runs in-process on a Frame's vector set (typically 500–5000 rows × 1536 dims = ~30MB).

## Decision

### Stage-by-stage
- **Frame** — founder-authored. Carries description, list of saved searches (source + query), money-gate threshold, kill_condition. No model involvement.
- **Gather** — per-saved-search. Fetches raw `JobPosting` records from the source (Upwork v1). On insert, computes and persists the embedding via the OpenAI Embeddings API. Embed-once: never recomputed after initial Gather.
- **Cluster** — runs in-process. Reads embeddings for the Frame's `JobPosting` rows, runs a deterministic clustering algorithm, produces `Candidate` records with computed centroids. Across reruns, new clusters are matched to existing Candidates by centroid cosine similarity above a threshold; matched Candidates retain their ID (and their RedTeamVerdicts); unmatched-new clusters get fresh IDs; unmatched-old Candidates are dropped (verdicts on dropped Candidates are deleted with them — overwrite semantics per Three Amigos rule 11).
- **Score** — per `JobPosting` within each Candidate. Evaluates the Frame's money gate, writes a `gate-classification` field on `PaidJobSignal` (no record creation/deletion when threshold moves — see rule 8 of story 743). Aggregates into the Candidate's score field.
- **Red-team** — one Candidate at a time, conversational with the agent. Produces a `RedTeamVerdict` per Candidate that overwrites Score's verdict.
- **Board** — assembled view over Frame's Candidates plus their verdicts.

### Agent surface (MCP tools)
- `list_candidates(frame_id)` — agent reads the Cluster output for labeling.
- `label_candidate(candidate_id, label)` — agent assigns a semantic name.
- `merge_candidates(candidate_ids)` — agent merges over-fragmented clusters.
- `split_candidate(candidate_id, partition_spec)` — agent splits over-aggregated clusters.
- Red-team tools (per story 741) — verdict prosecution per Candidate.

Merge/split mutate Candidate membership directly and recompute centroids; they do not re-run KMeans. This keeps Candidate identity stable through agent refinements.

### What MMS does NOT do
- No semantic naming of clusters by MMS code.
- **No LLM *completion* calls initiated by MMS.** The OpenAI Embeddings call on Gather is the single allowed exception — it's a model API call, but it's not narrative/judgment work. The bright-line rule: MMS may compute vectors; MMS may not generate prose, scores, or verdicts.
- No clustering "quality judgment" by MMS — that's the agent's job through the 3-pass refinement (`SetPainDescriptor` → `MergeCandidates`/`SplitCandidate` → `LabelCandidate`), guided by the problem-discovery skill (see `problem-discovery-skill.md`).

### The 3-pass agent refinement (Cluster phase)
KMeans on embeddings is a **seed partition** — fast, deterministic, but based on text-surface similarity rather than underlying pain semantics. The agent reshapes the seed via three passes guided by the skill:

1. **Describe pain per JobPosting** — agent reads each JobPosting in each Candidate and calls `SetPainDescriptor` with a structured one-line description of the underlying pain (e.g., "vendor portal UX friction" vs. "compliance bottleneck during onboarding"). Per-posting, not per-cluster.
2. **Consolidate or split based on descriptor similarity** — agent reviews descriptors within each Candidate; if descriptors diverge, `SplitCandidate` partitions the Candidate by descriptor group; if two Candidates have similar descriptors, `MergeCandidates` combines them.
3. **Name** — agent calls `LabelCandidate` with a descriptor-grounded name.

This is the canonical semantic clustering work; KMeans only exists to give the agent a sensible starting partition rather than forcing it to cluster N postings from scratch.

## Consequences
- **Pro:** RedTeamVerdict persistence works simply via `belongs_to Candidate` with stable IDs across reruns. No verdict-orphaning heuristics needed.
- **Pro:** Sub-second cluster reruns. Sam can experiment with adding sources or refining the Frame without rebuilding the pipeline.
- **Pro:** Harness principle preserved for all narrative/judgment work. MMS bills are deterministic and dominated by embedding costs (under $1/month at solo-founder scale; see `openai-embeddings.md`).
- **Pro:** Centroid matching uses pgvector's cosine operator natively (one query per cluster) — see `pgvector.md`.
- **Con:** Two systems own different aspects of the Candidate (MMS owns membership and centroid, agent owns label). Tool surface for merge/split adds design work.
- **Con:** When the founder adds a saved search and a flood of new JobPostings enters the corpus, re-clustering may shift membership enough to break centroid matching for some old Candidates. Policy: matched-by-centroid above similarity threshold → Candidate kept (verdicts persist); below threshold → Candidate dropped with its verdicts. Tunable threshold is a future concern.
- **Con:** The embedding pass is the one ML/LLM dependency MMS owns. Vendor lock to OpenAI is mitigated by the small surface (a single API call); swap-out to Voyage or Cohere is a one-config change if needed.

See `openai-embeddings.md` for the embedding model choice, `pgvector.md` for the vector storage decision, `scholar.md` for the clustering algorithm, `problem-discovery-data-sources.md` for the data-source credentialing pattern, and `problem-discovery-skill.md` for the skill that guides the agent through this pipeline.
