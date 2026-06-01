# ElixirForum source returns category top-threads, not query-relevant matches

Filed 2026-05-26 from MMS MCP usage during the CodeMySpec marketing cycle. **Priority: medium** — ElixirForum venues now resolve (slug fix done same session) but return noise, so the EF side of every CMS search is effectively unusable for lead-scan.

## Problem

After fixing the stale venue slugs (`chat`/`your-libraries`/`phoenix-forum` → removed; `ai-llms`, `questions-help`, `dev-env-tools` configured and verified resolving), `run_search` returns ElixirForum candidates that **ignore the search query**. The adapter appears to return the category's top threads ranked by score/views, not threads matching the query terms.

Reproduction (2026-05-26 session):

| Search | Query | EF candidates returned (top titles) |
|---|---|---|
| 4 — "phoenix elixir AI claude agent coding copilot OTP" | (AI/agent/Phoenix intent) | "BEAM ordering guarantees", "Cannot install asdf erlang 24.1 on MacOS", "pretty-print XML string", "Erlang persistent_term vs constant terms" |
| ad-hoc — "claude agent harness tooling workflow" on `dev-env-tools` | (harness/tooling intent) | "Favorite programming chair?", "How fast is your internet connection?", "What mouse do you use?", "Which router do you use?" |

90 of 115 candidates on search 4 were ElixirForum, essentially all of them generic Erlang/install/gear threads. Zero matched the query intent. The Reddit side of the same searches returns query-relevant results, so this is EF-adapter-specific.

## Why it matters

1. **EF lead-scan yields nothing usable.** ElixirForum is a Tier-1 CMS venue (senior Phoenix engineers, the densest peer-engineer audience). If the adapter can't surface query-relevant threads, the agent can't find the AI-code-quality / harness / spec threads the searches are designed for, and the EF venues are dead weight in the candidate list.
2. **It dilutes ranking.** 90 irrelevant EF candidates crowd out the ~25 relevant Reddit ones in the unified, score-ranked list, and inflate payload size (feeds the separate pagination issue).
3. **It silently masquerades as "working."** No failures are returned — the slug fix looks complete — but the results are noise, so the breakage is easy to miss.

## Likely cause

The EF adapter probably hits the Discourse category endpoint (e.g. `/c/<slug>/<id>.json` or category latest/top) and returns the listing as-is, without passing the query to Discourse search. Discourse exposes `/search.json?q=<query>+category:<slug>` which does real full-text relevance ranking and supports category scoping.

## Proposed design

1. Route EF source through Discourse search (`/search.json?q=...`) with the query terms, scoped to the venue's category (`category:<slug>` or `#<slug>` filter), instead of the category listing endpoint.
2. Preserve the existing candidate envelope (title, url, source_thread_id, reply_count, score, recency, engagement).
3. Keep score/reply_count from the search payload where available; fall back to topic metadata.
4. Respect the per-source signal weight in the unified ranking so EF relevance scores are comparable to Reddit.

## Acceptance criteria

1. A CMS search with an AI/agent/spec query returns EF candidates whose titles/snippets are topically relevant to the query (manual check: search 1 "AI code quality verification" should surface AI/LLMs threads about code quality, not asdf-install threads).
2. Querying `dev-env-tools` for "claude agent harness" returns harness/tooling threads (e.g. "ElixirLS MCP Server", "Devcontainer for Elixir"), not "favorite chair / which mouse".
3. No `unknown_category` regressions; the slug set fixed on 2026-05-26 still resolves.
4. EF candidate count per search is bounded by relevance, not "the whole category."

## Out of scope

- Re-adding the dead slugs. The 2026-05-26 slug fix stands.
- Snippet/pagination changes — tracked in `run-search-result-pagination.md`.

## History

- 2026-05-26: fixed stale EF venue slugs (removed `chat`/`your-libraries`/`phoenix-forum`; added/verified `ai-llms`, `questions-help`, `dev-env-tools`). Verified zero `unknown_category` failures — but discovered EF results ignore query relevance. Slug config correct; relevance ranking is the remaining gap.

## Reference

- Caller-side: 2026-05-26 daily scan session in `code_my_spec_marketing`.
- Related: `run-search-result-pagination.md`, `search-recency-uses-mms-indexed-not-source-created.md`. Memory: `reference_elixirforum_venue_slugs`.
