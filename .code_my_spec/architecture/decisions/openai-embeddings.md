# Use OpenAI Embeddings for JobPosting Vectorization

## Status
Accepted

## Context
The problem-discovery feature (stories 739–743) needs a fixed-dimensional vector representation of each `JobPosting` so the Cluster stage can group postings into `Candidate` records and so cross-rerun cluster identity can be matched via centroid similarity (see `problem-discovery-clustering.md`).

The vectorization must be:
- **Cheap at solo-founder scale** — typical Frame: 50–500 JobPostings, run ~10 Frames per month.
- **Quality-good-enough for clustering** of short-to-medium English text (Upwork posting title + description, ~500 tokens average).
- **Deterministic** — same input text produces same vector, so re-embedding (if ever needed) yields stable results.
- **Operationally minimal** — no model hosting on the app server, no GPU dependency.

The constraint "MMS should be a harness, not an LLM-bearing application" tolerates ONE model dependency: the embedding pass. The bright-line rule: **MMS may compute vectors; MMS may not generate prose, scores, or verdicts.** All semantic work downstream (cluster labeling and refinement, Red-team prosecution) happens in the agent's context through the problem-discovery skill (see `problem-discovery-skill.md`).

### Options considered

**Local model via Bumblebee + Nx (e.g., sentence-transformers, BGE).**
- Pro: No API dependency, no per-call cost, no vendor lock.
- Con: Adds 500MB–2GB to the deployed image. Inference on CPU is slow (seconds per posting on a Hetzner shared CPU). Long-term means moving to a dedicated inference host — complex architecture for a solo-founder feature.
- Verdict: Rejected for v1.

**OpenAI `text-embedding-3-small`.**
- 1536 dims (reducible to 512 via the `dimensions` API parameter if storage becomes a concern; not needed for our scale).
- $0.02 per 1M tokens.
- Widely deployed, stable API, already in most founders' API key pile.
- Quality is sufficient for clustering English commercial text; not top of leaderboards but adequate for v1.

**OpenAI `text-embedding-3-large`.**
- 3072 dims, $0.13 per 1M tokens.
- Marginally better clustering quality. ~6.5× cost. At our scale that's still under $1/month, but no benefit until/unless we hit a quality wall.

**Voyage AI `voyage-3-lite` / `voyage-3-large`.**
- Strong on retrieval and clustering benchmarks at competitive prices ($0.02 / $0.18 per 1M tokens).
- One more vendor relationship; not already in the stack.
- Worth a swap if OpenAI quality proves insufficient.

**Cohere `embed-english-v3.0`.**
- $0.10 per 1M tokens, 1024 dims.
- Good multilingual support (not needed for English Upwork postings).
- One more vendor; no compelling differentiator for this use case.

### Cost projection

| Frames/month | Postings/Frame | Tokens/posting | Cost @ $0.02/1M | Cost @ $0.13/1M |
|---|---|---|---|---|
| 10 | 300 | 500 | $0.03 | $0.20 |
| 100 | 500 | 500 | $0.50 | $3.25 |

Even at 100×-current-scale with the expensive model, monthly cost stays under $5. Embedding cost is not a budget consideration.

## Decision

### Model
`text-embedding-3-small`, 1536 dimensions (no reduction).

### When embeddings are computed
On Gather, per `JobPosting` insert. Embed-once: the embedding is persisted on the `JobPosting` row and never recomputed. Re-clustering reads vectors from the database, not from the embedding API. Tightening the money-gate threshold (which only reruns Score) does not touch the embedding API. Adding a new saved search only embeds the newly-gathered postings.

### Input text shape
Concatenate `title \n\n description`, trimmed to the embedding model's input limit (8191 tokens for `text-embedding-3-small`). For Upwork postings this limit is never reached in practice.

### Failure handling
A failed embedding on Gather is fatal for that individual `JobPosting` insert — the row is not persisted without its vector, because downstream Cluster requires a complete vector set per Frame. The Gather stage logs the failure and continues with the next posting. The founder sees a per-saved-search "N gathered, M failed" report.

### API client
Prefer `ReqLLM` if it provides clean embedding-endpoint coverage; fall back to a direct Req call (per the `req.md` ADR — Req is the HTTP client for new code) otherwise. The embedding endpoint is one POST with a JSON body, so the SDK savings are modest either way.

### Configuration
App-level API key sourced from environment configuration (`OPENAI_API_KEY` in `envs/<env>.env`), **not** the per-account `Integrations` context. This is a departure from the Reddit / ElixirForum / Google pattern, which uses per-account OAuth via Integrations. The rationale: `Integrations` is shaped for user-level OAuth flows (consent screen, refresh tokens, per-account credentials), whereas the OpenAI Embeddings API is an unattended service-account credential the application uses on the founder's behalf. See `problem-discovery-data-sources.md` for the broader policy on data-source credentialing in ProblemDiscovery.

## Consequences
- **Pro:** Effectively zero operational cost at solo-founder scale; not even a budget conversation.
- **Pro:** Zero hosting burden — no model weights in the image, no inference process to supervise.
- **Pro:** App-level API key keeps the v1 surface tiny — one env var, no UI, no encrypted-credentials lifecycle. The trade is that all founders share the bill; revisit when MMS goes multi-tenant beyond the founder's own account.
- **Pro:** Swap to Voyage or another embedding API is a one-config change (model name + endpoint) — surface is tiny.
- **Con:** Network dependency on Gather. An OpenAI outage blocks new Gather runs but does not affect re-clustering, re-scoring, or any other pipeline stage (vectors are persisted).
- **Con:** Vendor lock to OpenAI's specific 1536-dim vector space. Switching providers later requires re-embedding the corpus (cheap and cron-able, but not free).
- **Con:** App-level credentials mean MMS owes a per-account proxy or rebill model when multi-tenant. The cleanest future migration path is shifting to per-account via Integrations when usage warrants it.

See `problem-discovery-clustering.md` for the architectural decision that creates this dependency, `pgvector.md` for vector storage, `scholar.md` for the clustering algorithm.
