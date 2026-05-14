# QA Brief — Story 705: Discover engagement opportunities across social platforms

## Tool

`mix test` (ExUnit spex runner for unit-level BDD tests); `curl` for MCP endpoint checks.

## Auth

The MCP endpoint at `/mcp` requires an OAuth bearer token (`Authorization: Bearer <token>`).
Bearer tokens are issued via the OAuth flow at `/oauth/token` after a client application is
registered at `/oauth/register`. For the spex-level tests, no HTTP auth is needed because
the spex call `SearchEngagements.execute/2` directly in-process using a synthesized Anubis
frame carrying an `account_scoped_user_fixture()` scope.

For endpoint-level curl probes:
- Unauthenticated: `curl -sS http://127.0.0.1:4008/mcp` returns `401`.
- With invalid token: `curl -sS -H "Authorization: Bearer bad" http://127.0.0.1:4008/mcp` returns `{"error":"unauthorized"}`.

No browser auth is needed for this story — all behavioral testing is at the spex (unit) level.

## Seeds

No database seeds are required for the spex tests. Each spex calls
`Fixtures.account_scoped_user_fixture()` which creates an isolated user and account in the
test sandbox. The function is idempotent within a single test run (each call creates a new
account).

## What To Test

### Spex suite (18 BDD spex files via `mix test`)

Run all 18 spex files one batch at a time:

```
mix test \
  test/spex/705_discover_engagement_opportunities_across_social_platforms/criterion_6119_*.exs \
  test/spex/705_discover_engagement_opportunities_across_social_platforms/criterion_6120_*.exs \
  test/spex/705_discover_engagement_opportunities_across_social_platforms/criterion_6121_*.exs \
  ...
```

Expected: all 18 tests pass.

### Criterion-by-criterion coverage

- **6119** — LLM calls `search_engagements` with a keyword query and receives a ranked list: assert `isError` is false, response has `candidates` key (list).
- **6120** — Reddit + ElixirForum satisfy the Source behaviour: `Reddit.validate_venue("elixir")` returns `:ok`; `Reddit.search/2` and `ElixirForum.search/2` return `{:ok, list()}`.
- **6121** — Each candidate has: `title`, `source`, `url`, `score`, `reply_count`, `recency`, `snippet`. (Passes at scaffold stage because list is empty; shape is asserted on any present candidates.)
- **6122** — Two identical calls return the same candidate count; no duplicate URLs in the list.
- **6123** — Tool envelope is not an error even if underlying sources could fail; `candidates` key is always present.
- **6124** — Tool works without `venue` filter; tool works with `venue: "elixir"` filter; `candidates` key present in both cases.
- **6162** — Two separate accounts each get their own scoped (empty) candidate lists; no cross-account leakage.
- **6163** — Account with no enabled venues returns empty candidate list without error.
- **6164** — Both `Reddit.search/2` and `ElixirForum.search/2` return lists; any returned candidates carry the required shape fields and correct `source` value.
- **6165** — Two identical calls return same candidate count; no duplicate URLs.
- **6166** — Any present candidates are sorted by descending rank score.
- **6167** — (same ordering check at per-venue signal level — scaffold passes with empty list).
- **6168** — Tool never errors even if a source adapter fails; `candidates` always a list.
- **6169** — With no enabled venues (all sources absent), envelope not an error and `candidates` is empty.
- **6170** — First page call succeeds; cursor parameter (`cursor: "page2-cursor-token"`) is accepted without error.
- **6171** — (cross-source ordering — verified via rank descending sort check on any present candidates).
- **6172** — (recency shape check — passed vacuously at scaffold stage since candidates list is empty).
- **6173** — Total candidates <= 50 (25 per source × 2 sources); per-source count <= 25.

### MCP endpoint probe (curl)

- `GET http://127.0.0.1:4008/mcp` without auth header → 401.
- `POST http://127.0.0.1:4008/mcp` with `Authorization: Bearer invalid` → `{"error":"unauthorized"}`.
- `GET http://127.0.0.1:4008/.well-known/oauth-authorization-server` → 200 with JSON metadata.

### Tool registration check

- Verify `SearchEngagements` is registered (or not) in `MarketingStrategyServer` and document the finding.

## Result Path

`.code_my_spec/qa/705/result.md`
