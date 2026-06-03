# ProblemDiscovery Data Sources Use Small Req Clients With App-Level API Keys

## Status
Accepted

## Context
The ProblemDiscovery feature (stories 739–743) needs to fetch raw `JobPosting` records from external data sources — Upwork in v1, potentially other job boards or marketplaces later — and to call the OpenAI Embeddings API on each gathered posting (see `openai-embeddings.md`).

The existing convention in this codebase for external integrations is the `MarketMySpec.Integrations` context: per-account encrypted OAuth credentials with a provider behaviour (Reddit, ElixirForum, Google, GitHub, Codemyspec). It was built for user-level OAuth flows — consent screens, refresh tokens, per-account credentials the user authorized.

ProblemDiscovery's data sources are different in shape:
- **Upwork API access is a service account credential** — an API key the application holds on the founder's behalf, no user OAuth dance.
- **OpenAI Embeddings is an unattended service call** — same shape: API key, application credential.
- **The pluggable-source behaviour in story 740 needs a clean contract for "given a saved search, return JobPostings"** — not a full OAuth provider abstraction.

Using `Integrations` for these would mean shoehorning service-account credentials into a user-OAuth-shaped storage layer, building a fake "OAuth provider" for sources that don't have an OAuth flow, and paying for encrypted per-account credentials when v1 is a single-tenant founder app. The harness principle ("MMS is a harness, not an LLM-bearing application") also discourages MMS from accumulating elaborate credential management it doesn't need yet.

### Options considered

**Reuse `MarketMySpec.Integrations`.**
- Pro: One pattern for all external calls, consistent credential storage.
- Con: Integrations is shaped for OAuth — providers, refresh tokens, consent. Awkward fit for static API keys.
- Con: Adds per-account encrypted-credential UI / migration / lifecycle work for v1 that solves no current problem.

**Small Req clients per source, app-level API keys via env config.**
- Pro: Minimal surface — one Req module per source, one env var per source, done.
- Pro: Matches what the v1 deployment already has (Hetzner Docker Compose with `envs/<env>.env` files per `dotenvy.md`).
- Pro: Source behaviour (story 740) becomes a clean contract: `@callback search(saved_search :: t()) :: {:ok, [JobPosting.attrs()]} | {:error, term()}`. No credential plumbing in the contract.

**Hybrid — Integrations for OAuth-shaped sources, env config for API-key sources.**
- Possible long-term, but no current OAuth-shaped data source in the discovery pipeline.

### Why small Req clients win for v1
- Every current and near-term data source is API-key-shaped, not OAuth-shaped.
- The single-tenant deployment doesn't yet need per-account credential storage.
- Departing from `Integrations` here keeps both patterns honest: Integrations stays focused on user-OAuth flows, ProblemDiscovery's source layer stays focused on the "fetch postings" contract.

## Decision

### Pattern
Each data source is implemented as a child module of `MarketMySpec.ProblemDiscovery.Source`, conforming to the `MarketMySpec.ProblemDiscovery.Source` behaviour:

```elixir
defmodule MarketMySpec.ProblemDiscovery.Source do
  @callback search(saved_search :: SavedSearch.t()) ::
              {:ok, [posting_attrs :: map()]} | {:error, term()}
end
```

For Upwork v1: `MarketMySpec.ProblemDiscovery.Source.Upwork` is a small Req-based client. The implementation:
1. Reads the API key from application config at call time (`Application.fetch_env!(:market_my_spec, :upwork_api_key)`).
2. Composes the Upwork search request from the `SavedSearch`'s `source` + `query` fields.
3. Returns a list of `JobPosting` attribute maps (raw fields the schema can `cast/3`).
4. Handles HTTP errors, rate limits, and pagination per Upwork's API contract.

The OpenAI Embeddings client is a separate module (`MarketMySpec.ProblemDiscovery.Embeddings`) used by the Gather stage to embed each `JobPosting` on insert. Same shape: Req or ReqLLM, app-level API key, focused single-purpose module.

### Configuration
API keys live in environment configuration per `dotenvy.md`:
- `OPENAI_API_KEY` — used by `Embeddings`
- `APIFY_API_TOKEN` — used by `Source.Upwork` (Upwork has no public REST API with static-token auth, so we drive scraping through Apify's actor platform — same approach as the broken_oaths pipeline that seeded this feature). The default actor is `upwork-vibe~upwork-job-scraper`; the actor id is overridable per-deployment via `Application.put_env(:market_my_spec, MarketMySpec.ProblemDiscovery.Source.Upwork, actor: "custom/actor")`.

Dotenvy loads these into `Application.put_env/3` at boot via `config/runtime.exs`; the source modules read them at call time (allowing test overrides). Each new source ADR adds the corresponding env var.

### Testing
Per `req-cassette.md`, all Req-based clients in new code use `ReqCassette` for HTTP recording. The first test run records the real Upwork / OpenAI response; subsequent runs replay the cassette. Cassettes are committed under `test/fixtures/cassettes/`. API keys in cassettes are scrubbed at record time.

### What this is NOT
- Not an "Integrations replacement" — Integrations stays exactly as it is, used by Reddit / ElixirForum / Google / GitHub / Codemyspec for user OAuth.
- Not multi-tenant credential storage — when MMS adds founders beyond the single user, the migration target is shifting these sources into Integrations (with a service-account credential type) or building a new lightweight per-account API-key store. Both deferred until a real user shows up.
- Not a generalized "external API" pattern — it's the pattern for ProblemDiscovery's data sources. Other contexts pick the right pattern for their domain.

## Consequences
- **Pro:** v1 ships with one env var per source. Zero credential UI to build, zero per-account encryption lifecycle.
- **Pro:** The Source behaviour is small and testable; adding a new source is "implement one callback, add one env var, write one cassette."
- **Pro:** Keeps `Integrations` semantically pure (user OAuth) rather than diluting it into "any external credential."
- **Con:** Two patterns in the codebase — `Integrations` for user-OAuth flows, env-config Req clients for service-account flows. Future readers need to know which is which. Mitigated by this ADR and the source-behaviour module's documentation.
- **Con:** Migration cost when MMS goes multi-tenant: every source needs to learn how to read per-account credentials. The Source behaviour shape isolates this — only the source impls change, not the rest of ProblemDiscovery.
- **Con:** App-level credentials in env vars mean the same OpenAI / Upwork key applies to all activity on the deployment. Acceptable for solo-founder v1; first multi-tenant user triggers a migration.

See `problem-discovery-clustering.md` for the architectural context, `openai-embeddings.md` for the embedding-specific credential decision, and `req.md` / `req-cassette.md` for HTTP client + testing conventions.
