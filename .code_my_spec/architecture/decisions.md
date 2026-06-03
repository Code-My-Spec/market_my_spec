# Architecture Decisions

Index of all architecture decision records for Market My Spec. Each record captures the context, options considered, decision, and consequences.

## Accepted

### Core stack (pre-made for the standard CodeMySpec stack)

- [Elixir](decisions/elixir.md) — primary language
- [Phoenix](decisions/phoenix.md) — web framework
- [Phoenix LiveView](decisions/liveview.md) — interactive UI
- [Tailwind CSS](decisions/tailwind.md) — styling
- [DaisyUI](decisions/daisyui.md) — component library
- [Dotenvy](decisions/dotenvy.md) — environment management
- [Resend (with Swoosh)](decisions/resend.md) — transactional email
- [phx.gen.auth](decisions/phx-gen-auth.md) — authentication scaffold
- [PowAssent + cms_gen integrations](decisions/pow-assent-integrations.md) — OAuth providers, multi-tenancy, feedback widget
- [Hetzner + Docker Compose](decisions/hetzner-deployment.md) — deployment

### Testing

- [BDD with SexySpex + Wallaby](decisions/bdd-testing.md) — behavior-driven specs
- [Wallaby](decisions/wallaby.md) — browser-based integration tests
- [ExVCR](decisions/exvcr.md) — HTTP recording for HTTPoison-based tests (PowAssent/ExAws)
- [ReqCassette](decisions/req-cassette.md) — HTTP recording for Req-based tests (Engagements context); ExVCR stays for legacy HTTPoison code

### Market My Spec specifics

- [Anubis MCP](decisions/anubis-mcp.md) — MCP server over SSE for skill exposure
- [ex_oauth2_provider](decisions/ex-oauth2-provider.md) — OAuth authorization server for MCP client authentication

### Engagements feature

- [Req](decisions/req.md) — HTTP client for all new code in the Engagements context
- [Reddit integration](decisions/reddit-integration.md) — script app OAuth, password grant, rate-limit back-off, UTM scheme
- [Discourse integration](decisions/discourse-integration.md) — anonymous read, User API Key for posting, ElixirForum trust levels, UTM scheme

### Touchpoint prose linting

- [Vale](decisions/vale.md) — Vale CLI shelled out per request, per-account `.vale.ini` + style rules stored on the Account, JSON output surfaced in the Touchpoint editor

### Problem-discovery feature

- [Problem-discovery clustering architecture](decisions/problem-discovery-clustering.md) — Path C hybrid: algorithmic clustering for stable Candidate identity, agent-driven labeling and refinement (merge/split) via MCP. Preserves the harness principle while keeping RedTeamVerdicts persistent across reruns.
- [OpenAI embeddings](decisions/openai-embeddings.md) — `text-embedding-3-small` (1536 dims) on Gather, embed-once per JobPosting, app-level API key via env config (prefer ReqLLM client, fall back to Req)
- [pgvector](decisions/pgvector.md) — `vector(1536)` storage on JobPosting and Candidate centroid, base image swap to `pgvector/pgvector:pg17`, no index at v1 scale, centroid match via cosine `<=>` operator
- [Scholar](decisions/scholar.md) — `Scholar.Cluster.KMeans` in-process via Nx/EXLA, deterministic seed, auto-K via silhouette sweep over K ∈ {3..8}
- [ProblemDiscovery data sources](decisions/problem-discovery-data-sources.md) — small Req clients per source (Upwork v1), app-level API keys via env config, Source behaviour contract; NOT routed through Integrations (which stays focused on user OAuth)
- [Problem-discovery skill](decisions/problem-discovery-skill.md) — `MarketMySpec.Skills.ProblemDiscovery` + `McpServers.ProblemDiscovery.Resources.{SkillOrientation, Step}` mirroring the MarketingStrategy skill pattern; encodes the canonical procedure (Sales-Safari vocabulary audits in Frame, 3-pass cluster refinement, per-Candidate conversational Red-team)
