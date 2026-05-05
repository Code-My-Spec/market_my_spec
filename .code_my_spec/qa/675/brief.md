# QA Brief — Story 675: Skill Behavior Exposed Over MCP (SSE)

## Tool

curl (for OAuth metadata and /mcp probes); static file-system audit via Read tool; no browser interaction required (no UI pages involved).

## Auth

Bearer token is required for `/mcp`. Due to sub-agent constraints that block minting OAuth bearer tokens programmatically via `mix run -e`, bearer-authenticated MCP tool/resource calls are SKIPPED. Unauthenticated probes (401 responses, well-known metadata) are fully testable.

Scripts available but unused for this session:
- `.code_my_spec/qa/scripts/exchange_github_token.sh`
- `.code_my_spec/qa/scripts/exchange_google_token.sh`

## Seeds

No seed data required for static audit or unauthenticated endpoint probes.

## What To Test

### Static Audit

1. Confirm `MarketMySpec.McpServers.MarketingStrategyServer` advertises `:tools` and `:resources` capabilities.
2. Confirm registered tools: `StartInterview`, `WriteFile`, `ReadFile`, `ListFiles`.
3. Confirm registered resources: `SkillOrientation`, `Step`.
4. Confirm `lib/market_my_spec_web/controllers/mcp_controller.ex` delegates to `Anubis.Server.Transport.StreamableHTTP.Plug`.
5. Confirm `priv/skills/marketing-strategy/SKILL.md` exists and contains `name: marketing-strategy` and references to step files.
6. Confirm all 8 step files exist under `priv/skills/marketing-strategy/steps/`.

### Spex Anemia Audit

7. Read all 9 spex files under `test/spex/675_skill_behavior_exposed_over_mcp_sse/` and classify each as substantive (exercises real HTTP or MCP interactions with behavioral assertions) or anemic (file-content checks, static assertions, or OAuth scaffolding that will fail because `/oauth/register` etc. are not yet wired).

### Curl Probes

8. `curl -i -X POST -H "Content-Type: application/json" http://localhost:4008/mcp` → expect 401 with `WWW-Authenticate: Bearer ...`
9. `curl -i http://localhost:4008/.well-known/oauth-authorization-server` → expect 200 with OAuth metadata JSON
10. `curl -i http://localhost:4008/.well-known/oauth-protected-resource` → expect 200 with protected-resource JSON
11. `curl -i -X GET -H "Accept: text/event-stream" http://localhost:4008/mcp` → observe response; note if 401 (good) or other status; note any SSE transport issues

### OAuth Metadata Cross-Check

12. Compare issuer/endpoint URLs in `/.well-known/oauth-authorization-server` against actual server port (4008) — flag mismatches.

## Result Path

`.code_my_spec/qa/675/result.md`
