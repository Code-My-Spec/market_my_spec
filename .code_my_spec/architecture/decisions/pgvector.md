# Use pgvector for Vector Storage and Centroid Matching

## Status
Accepted

## Context
The problem-discovery feature (stories 739–743) persists a 1536-dimensional embedding per `JobPosting` (see `openai-embeddings.md`) and uses centroid cosine similarity to match newly-clustered Candidates against prior runs' Candidates (see `problem-discovery-clustering.md` for the Candidate identity stability mechanism).

Operations needed against the vectors:
1. **Store** one `vector(1536)` per `JobPosting`.
2. **Bulk read** all vectors for a Frame's JobPosting rows into memory for the Scholar clustering pass (see `scholar.md`).
3. **Centroid match across reruns**: given a freshly computed cluster centroid, find the most similar prior `Candidate` centroid for the same Frame (cosine similarity above a threshold → same Candidate ID; below → new Candidate). One query per new cluster.

No semantic search, no nearest-neighbor recommendations, no large-scale ANN — at solo-founder scale (50–5000 vectors per Frame) sequential scans are faster than approximate-nearest-neighbor indices.

### Options considered

**pgvector with `vector(1536)` column type.**
- Postgres extension, mainstream since 2023, packaged in the `pgvector/pgvector:pg17` Docker image.
- Native cosine distance operator `<=>` for centroid matching in one query.
- Ecto integration via the `pgvector` hex package — `field :embedding, Pgvector.Ecto.Vector`.

**`:binary` column storing serialized 32-bit floats.**
- Works without an extension.
- Requires custom encoder/decoder; cosine similarity must be computed in Elixir after bulk-loading.
- Centroid matching becomes "load all centroids, compute cosine for each, pick the max" — workable but reinvents what pgvector does idiomatically.
- Verdict: Rejected — the storage savings are illusory (binary and `vector` types are both 6KB per 1536-dim row), the operator-less pattern is a future foot-gun.

**JSON array column.**
- Stores as `[0.123, -0.456, ...]`. No special tooling needed.
- Slow to deserialize; ugly in psql; cannot use any vector operators.
- Verdict: Rejected — wrong tool for the job.

**Separate vector database (Qdrant, Weaviate, etc.).**
- Operational overhead of a second datastore for a feature that needs ~5000 vectors per Frame.
- Verdict: Massive overkill.

### Why pgvector
- It is the idiomatic Postgres-native answer for this shape of problem; using anything else would surprise future readers of the codebase.
- The centroid-matching query is one SQL statement: `SELECT id FROM candidates WHERE frame_id = $1 ORDER BY centroid <=> $2 LIMIT 1`.
- Operationally trivial: install the extension, run `CREATE EXTENSION vector;`, swap the Postgres base image. Hetzner Docker Compose deployment is unaffected.

## Decision

### Extension
Install via the `pgvector/pgvector:pg17` Docker image, replacing the stock `postgres:17` image in `docker-compose.yml` for all environments. The image is drop-in compatible — same Postgres binary, just with the `vector` extension package included.

A migration creates the extension on each environment:

```elixir
def up do
  execute "CREATE EXTENSION IF NOT EXISTS vector"
end
```

### Schema columns
- `job_postings.embedding` — `vector(1536)`, NOT NULL. Computed and persisted on Gather (see `openai-embeddings.md`).
- `candidates.centroid` — `vector(1536)`, NOT NULL. Computed on Cluster and on every Candidate-membership mutation (merge / split). Mean of member `JobPosting` embeddings.

### Indexing
**No vector index in v1.** At Frame-level cardinality (max ~5000 vectors per Frame, max a few hundred Candidates per Frame), sequential scan with the cosine operator outperforms ivfflat / hnsw indices. Index strategies cost build time and storage and are tuned for million-row tables.

Revisit if a Frame ever crosses 50K JobPostings — but realistic Upwork search volume per Frame plateaus well below that.

### Centroid matching query
Per fresh cluster centroid produced by Scholar:

```elixir
from(c in Candidate,
  where: c.frame_id == ^frame_id,
  order_by: cosine_distance(c.centroid, ^new_centroid),
  limit: 1,
  select: {c.id, cosine_distance(c.centroid, ^new_centroid)}
)
```

If the returned distance is below a configured threshold (initial guess: 0.15 cosine distance, equivalent to ~0.85 cosine similarity), the new cluster inherits that Candidate's ID and RedTeamVerdicts persist. Otherwise a fresh Candidate is created.

### Elixir package
Add `{:pgvector, "~> 0.3"}` to `mix.exs`. Use `Pgvector.Ecto.Vector` as the field type and `Pgvector.Ecto.Query` for the `cosine_distance/2` Ecto fragment.

## Consequences
- **Pro:** Idiomatic, well-supported. The vector column type, cosine operator, and Ecto integration are all first-class.
- **Pro:** The centroid-matching query is one statement, runs sub-millisecond at Frame scale.
- **Pro:** Bulk-read of a Frame's vectors into Nx tensors for Scholar is a single `SELECT` with no deserialization gymnastics — the `pgvector` package returns `Pgvector` structs that convert to Nx tensors directly.
- **Con:** Postgres base image swap requires careful coordination on first deploy — both dev, UAT, and prod compose files need updating. Stock data is preserved; only the binary changes.
- **Con:** Drops support for any future "I want to use SQLite for dev" path. Not on the roadmap.
- **Con:** Storage: 1536-dim vector = ~6KB per row. At 5000 JobPostings per Frame × 10 Frames per founder = 300MB per founder per year. Negligible.

See `problem-discovery-clustering.md` for the architectural use, `openai-embeddings.md` for where vectors come from, `scholar.md` for what they feed into.
