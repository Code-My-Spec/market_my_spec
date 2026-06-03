# Use Scholar.Cluster.KMeans for In-Process Clustering

## Status
Accepted

## Context
The Cluster stage of the problem-discovery pipeline (stories 739–743) groups a Frame's `JobPosting` rows into `Candidate` records using their persisted embeddings (see `openai-embeddings.md` and `pgvector.md`). Stable Candidate identity across reruns is achieved by centroid cosine matching, so the algorithm must produce well-defined centroids and behave deterministically given fixed inputs and a fixed seed (see `problem-discovery-clustering.md` for the full Path C architecture).

The clustering pass:
- Runs in-process inside the Phoenix app.
- Operates on a single Frame's vector set (typically 50–5000 vectors × 1536 dims; about 30MB max).
- Must complete in well under a second so reruns feel free.
- Must be deterministic with a fixed seed so re-clustering the same input yields stable Candidate IDs.

The harness principle ("MMS is a harness, not an LLM-bearing application") tolerates ML libraries that run locally on CPU and don't make model calls. Pure-Elixir Nx-backed numerics qualify.

### Options considered

**Scholar (Nx-backed ML library, Elixir-native).**
- Pure Elixir, sits on Nx with EXLA for CPU acceleration.
- Several clustering algorithms in the `Scholar.Cluster.*` namespace: `KMeans`, `DBSCAN`, `AffinityPropagation`, `GaussianMixture`, `OPTICS`.
- Already in the Elixir ML ecosystem; no Python interop, no shell-out.

**Python shell-out to scikit-learn.**
- Maximum algorithm choice and battle-tested implementations.
- Adds a Python runtime to the Docker image (200MB+), a `System.cmd` surface, serialization of the vector input through stdin/file.
- Verdict: Rejected — Scholar covers the algorithms we need with no external runtime.

**Hand-rolled KMeans in pure Elixir.**
- Minimal dependency.
- Wastes time reinventing well-tested numerics; floating-point edge cases are easy to get wrong.
- Verdict: Rejected.

### Algorithm choice within Scholar

| Algorithm | K upfront? | Outlier handling | Centroid for stability | Notes |
|---|---|---|---|---|
| `Scholar.Cluster.KMeans` | Required | None — forces every point into a cluster | Native, mean of cluster members | Simplest, deterministic with seed, clean centroids. |
| `Scholar.Cluster.DBSCAN` | No | Native noise label (-1) | None natively (compute post-hoc) | Better fit for "some postings don't represent a real cluster" but sensitive to the `eps` parameter and lacks built-in centroids. |
| `Scholar.Cluster.AffinityPropagation` | No | Sort of (exemplars) | Exemplar = natural centroid | Slower, less common, "principled" but heavier. |
| `Scholar.Cluster.GaussianMixture` | Required | None | Yes | Soft (probabilistic) membership; overkill for v1. |

**KMeans wins for v1:**
- Deterministic with a fixed seed — same input vectors produce the same Candidate set, which means stable Candidate IDs even before centroid matching kicks in.
- Centroids are natural to the algorithm, which is exactly what the cross-rerun matching mechanism in `pgvector.md` requires.
- "Forces every point into a cluster" is acceptable because Score is the second filter — a weak-fit posting joins its nearest cluster but gets `gated_out` because its money signal is weak. The Candidate's aggregate score remains representative.
- The unknown-K problem is addressable via silhouette score search over a small K range — cheap at Frame scale.

DBSCAN remains a fallback if KMeans's "every point clustered" behavior proves wrong-feeling in practice. Swap is a one-module change inside the Cluster context.

## Decision

### Library
Add `{:scholar, "~> 0.4"}` and `{:exla, "~> 0.10"}` to `mix.exs`. Configure Nx to use EXLA as the default backend for CPU acceleration.

### Algorithm
`Scholar.Cluster.KMeans.fit/2` with:
- A configured `seed:` option for determinism.
- `init_strategy: :k_means_plus_plus` for stable initialization.
- `num_clusters:` selected by silhouette-score search over `K ∈ {3, 4, 5, 6, 7, 8}` for v1. Skipped when the founder pins K via a Frame parameter (future story).

### K selection
For each candidate K, run KMeans, compute the silhouette score over the resulting assignments, and pick the K with the highest score. At Frame scale (≤5000 vectors), the full sweep completes in sub-second.

If the Frame artifact carries an explicit `num_clusters` value (future enhancement), use it directly and skip the sweep.

### Centroid extraction
After fitting, `Scholar.Cluster.KMeans` exposes the cluster centroids as an Nx tensor. Convert each row to a `Pgvector.new/1` value and persist on the corresponding `Candidate` row.

### When clustering runs
- On explicit user / agent invocation of the Cluster stage for a Frame.
- Never automatically on Gather (Gather only persists embeddings, doesn't trigger clustering).
- Never automatically on Score (changing the money gate does not change cluster membership — see story 743 rule 5).

### Determinism guarantees
- Same input vectors + same `seed:` + same K → same cluster assignments and centroids. Verified in a unit test per Cluster context.
- This determinism is the first line of defense for Candidate ID stability; the pgvector centroid match (see `pgvector.md`) is the second line, kicking in only when the input vector set changes (founder added a saved search, postings were added).

## Consequences
- **Pro:** Pure Elixir, no Python, no model server, no shell-out. The clustering pass slots into the Phoenix app as a normal function call.
- **Pro:** Sub-second clustering at Frame scale even with the silhouette K sweep, making reruns essentially free.
- **Pro:** Centroids fall out of the algorithm naturally — no post-hoc computation for the rerun-stability mechanism.
- **Pro:** Deterministic with a fixed seed, which materially simplifies the Candidate ID stability story and makes Cluster trivially testable.
- **Con:** EXLA adds compilation time on first build (~30 seconds for the CPU backend) and ~50MB to the image. Acceptable.
- **Con:** KMeans forces every point into a cluster. Some `JobPosting` rows will land in a Candidate they don't really belong to and get scored there. Mitigated by Score's per-posting gate-classification (low-fit postings get `gated_out` on money signal) and by the agent's merge/split refinement (Path C tool surface in `problem-discovery-clustering.md`).
- **Con:** K-selection via silhouette sweep is heuristic, not principled. If founders find the auto-K results wrong, exposing K as a Frame parameter is a future story.
- **Con:** Bound to Nx/EXLA versioning. The Elixir ML ecosystem has churned faster than Phoenix; pin the dep versions and revisit on a Phoenix upgrade cadence.

See `problem-discovery-clustering.md` for the architecture, `openai-embeddings.md` for input vectors, `pgvector.md` for storage and centroid matching.
