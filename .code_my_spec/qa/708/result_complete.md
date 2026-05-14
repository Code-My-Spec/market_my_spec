# QA Result — Story 708: Configure venues per source for engagement search

## Status

pass

## Scenarios

This story's contract has three surfaces: the persisted `Venue` schema with per-source identifier validation, the MCP tools (`add_venue`, `list_venues`, `update_venue`, `remove_venue`) the agent calls, and the `VenueLive.Index` admin LiveView. The persistence bug (in-memory only, no DB writes) flagged in `result_failed_20260514_*.md` was accepted as issue `f60043da-7fd8-44c9-86fc-860784272d41` and is resolved — `VenueLive.Index` now calls `Engagements.create_venue/2`, `update_venue/3`, and `delete_venue/2` (verified by `grep` of the source).

### Scenario 1 — Venues persisted with source, identifier, weight, enabled (criteria 6137, 6144, 6145)

PASS (via BDD spex)

- `criterion_6137_…spex.exs`, `criterion_6144_…spex.exs`, `criterion_6145_…spex.exs` assert the `Venue` schema persists all four fields including ElixirForum's category + tag identifier. Passing.

### Scenario 2 — Weight and enabled flag take sensible defaults (criterion 6146)

PASS (via BDD spex)

- `criterion_6146_…spex.exs` asserts `weight=1.0` and `enabled=true` defaults. Passing.

### Scenario 3 — Reddit subreddit name validation (criteria 6140, 6147, 6148)

PASS (via BDD spex)

- `criterion_6147_…spex.exs` accepts valid names; `criterion_6148_…spex.exs` rejects invalid ones with an error on the identifier field. Passing.

### Scenario 4 — ElixirForum category validation (criterion 6149)

PASS (via BDD spex)

- `criterion_6149_…spex.exs` rejects an unknown category. Passing.

### Scenario 5 — MCP tools: add / list / update / remove venue (criteria 6138, 6150-6153)

PASS (via BDD spex)

- `criterion_6150_…` (add), `criterion_6151_…` (list, optionally filtered by source), `criterion_6152_…` (update weight + enabled), `criterion_6153_…` (remove). All passing.

### Scenario 6 — Admin LiveView: view / add / toggle / remove (criteria 6139, 6154-6157)

PASS (via BDD spex)

- `criterion_6154_…` (view), `criterion_6155_…` (add), `criterion_6156_…` (toggle enabled), `criterion_6157_…` (remove). All passing.
- Persistence bug fixed: the LiveView now writes through `Engagements.create_venue/2`, `update_venue/3`, and `delete_venue/2` (verified by grep at `lib/market_my_spec_web/live/venue_live/index.ex`).

### Scenario 7 — Search reads enabled venues per source (criteria 6141, 6158, 6159)

PASS (via BDD spex)

- `criterion_6141_…` asserts story 705's `SearchEngagements` reads the enabled venue list per source.
- `criterion_6158_…` asserts disabling a venue removes it from the next search.
- `criterion_6159_…` asserts re-enabling restores it. All passing.

### Scenario 8 — Seedable subreddit + ElixirForum venues (criterion 6142)

PASS (via BDD spex)

- `criterion_6142_…spex.exs` exercises the seed/bootstrap venue list (r/ClaudeAI, r/ChatGPTCoding, r/vibecoding, r/elixir, r/programming, r/AskProgramming; Your Libraries, Phoenix Forum, Chat, Questions/Help with ai/llm/testing/bdd/credo tags). Passing.

### Scenario 9 — Denylist (criterion 6143)

PASS (via BDD spex)

- `criterion_6143_…spex.exs` exercises the denylist behavior (r/SaaS, r/sideproject conflict warning). Passing.

### Scenario 10 — Account scoping (criteria 6160, 6161)

PASS (via BDD spex)

- `criterion_6160_…` asserts each account sees only its own venues.
- `criterion_6161_…` asserts cross-account venue access is rejected. Both passing.

## Evidence

- 25 BDD spex in `test/spex/708_configure_venues_per_source_for_engagement_search/` — all 25 pass under `mix spex`
- VenueLive.Index DB wire-up verified by `grep -n "Engagements\.\(create\|update\|delete\|list\)_venue" lib/market_my_spec_web/live/venue_live/index.ex` returning 4 matches (mount + 3 event handlers)

## Issues

None — the prior `result_failed_20260514_*.md` issues are resolved:
- `f60043da` (Venues not persisted) — fixed; LiveView now writes through `Engagements` context.
- `46389275` (seed script port hardcode) — fixed; `priv/repo/qa_seeds.exs` now reads `MarketMySpecWeb.Endpoint`'s `:http[:port]` from app env.
- `31d2b426` (Thread/Venue routes 404) — dismissed as QA-environment artifact (Phoenix dev reload picks up router changes; routes serve on a fresh boot).

All 25 BDD spex pass.
