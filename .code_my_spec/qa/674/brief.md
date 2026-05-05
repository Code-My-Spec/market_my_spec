# QA Brief — Story 674: Start A Marketing Strategy Interview

## Tool

curl (MCP endpoint, no browser interaction needed — story 674 is MCP-endpoint-shaped, not LiveView-shaped)

Static file analysis: Read tool on priv/skills/marketing-strategy/SKILL.md and steps/03_persona_research.md

## Auth

MCP endpoint requires a bearer token obtained via OAuth flow. The bearer token minting path via `mix run -e` has proven unreliable (permission walls, single-boot cost). For this QA run:

- **Unauthenticated probe only:** `curl -i -X POST -H "Content-Type: application/json" http://localhost:4008/mcp`
- App is running on port **4008** (not 4007 as documented in the QA plan — plan needs updating)
- Authenticated MCP scenarios are SKIPPED in this run due to bearer token minting limitations

## Seeds

No seed data needed for this story — the scenarios are either:
1. Static file content assertions (SKILL.md and step files)
2. Unauthenticated endpoint probes

## What To Test

### Scenario 1 — Unauthenticated MCP request returns 401 with WWW-Authenticate (Criterion 5732)

```
curl -i -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/call","id":1,"params":{"name":"invoke_skill","arguments":{"skill_name":"marketing-strategy"}}}' \
  http://localhost:4008/mcp
```

Expected: HTTP 401, `www-authenticate: Bearer ...` header present

### Scenario 2 — SKILL.md static assertions (Criteria 5731, 5733, 5734, 5735, 5736, 5737, 5738, 5741, 5742)

Read `priv/skills/marketing-strategy/SKILL.md` and verify the following strings are present:
- `name: marketing-strategy`
- `steps/01_current_state.md` — **NOTE: spex 5731 asserts this but SKILL.md tree uses bare filenames like `01_current_state.md` without `steps/` prefix**
- `steps/08_plan.md` — **NOTE: same issue**
- `8-step`
- `Step 0`, `Orient`
- `Check whether \`marketing/\` already exists`
- `README.md`, `mix.exs`
- `before asking`
- `Don't make the user type things you can read`
- `Before touching anything`
- `The 8 steps`
- `restaurant`, `local business`
- `one or two questions at a time`
- `Adapt to the business type`
- `Do not default to dev-tool, SaaS, or tech examples`
- `unless the user's business is`
- `Don't batch` — **NOTE: spex 5737/5738 assert this capitalization; SKILL.md uses `don't batch` (lowercase)**
- `if the user bails after step 3` — **NOTE: spex 5737 uses lowercase `if`; SKILL.md uses `If` (uppercase)**
- `marketing/01_current_state.md`, `marketing/02_jobs_and_segments.md`, `marketing/03_personas.md`
- `Write artifacts as you go`
- `three usable files`
- `What this skill does NOT do`
- `blog posts`, `downstream content`
- `40-slide`, `analytics`

### Scenario 3 — Step 3 file assertions (Criteria 5739, 5740)

Read `priv/skills/marketing-strategy/steps/03_persona_research.md` and verify:
- `research agent`, `Dispatch`
- `parallel`, `in parallel`
- `marketing/research/persona_`
- `marketing/03_personas.md`
- `marketing/research/` appears before `marketing/03_personas.md` in the file
- `synthesize`, `research`

### Scenario 4 — StartInterview tool is a stub (Implementation Audit)

Read `lib/market_my_spec/mcp_servers/marketing_strategy/tools/start_interview.ex` and verify
whether the implementation is a smoke-test stub or real interview logic.

### Scenario 5 — Authenticated MCP tool calls (Criteria 5731–5742 behavioral tests)

SKIP — bearer token minting is not available in this QA run. The spex tests exercise these
criteria against static file content only (not real MCP exchanges) — see Issues section.

## Result Path

`.code_my_spec/qa/674/result.md`

## Setup Notes

- The app is running on port **4008**, not 4007. The QA plan documents 4007 — this needs updating.
- Criterion 5732 in the spex uses `context.conn` (the Plug.Test conn injected by the test framework) — it is NOT testing against the live server. The curl probe here tests the live server independently.
- Several spex assertion strings do not match SKILL.md content exactly (capitalization mismatches). These are flagged as issues and should be resolved before the spex can pass.
