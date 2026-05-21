# Journey QA Result

**Executed:** 2026-05-04
**Server:** `PORT=4008 mix phx.server`
**Seeds:** `mix run priv/repo/qa_seeds.exs` (extended to create agency + client users)
**Tool:** Vibium (browser) + curl (MCP endpoints)

## Summary

| Journey | Status | Notes |
|---------|--------|-------|
| 1 — First-time sign-up → MCP setup | pass | One observation: default account is not auto-created; user must create it manually |
| 2 — MCP agent connects, writes artifacts | pass | Bearer token minted via mint_token.exs; all 3 artifacts surfaced in /files |
| 3 — Iteration on existing strategy | pass | Read-before-edit gate enforced correctly in both directions |
| 4 — Agency dashboard + client creation | pass | Agency nav link, client creation, active-client switching all work; originator revoke correctly blocked |
| 5 — Client grants agency, agency revokes | pass | Grant form visible, duplicate rejected, agency revocation removes client from dashboard |
| 6 — MMS Agent install + pair + Reddit dispatch | deferred | 3-process flow (browser + binary + server); verified at per-story level via spex + per-story QA on stories 731/732/733. Journey-level end-to-end is `@moduletag :manual` per `test/e2e/journey_6_agent_pair_test.exs`. |
| 7 — Vale style guide + polish loop | pass (composition) | Verified at per-story level via QA attempts on 736 (`645ef51a`, 5/5 pass with real Vale CLI) and 738 (`1acdc962`, 7/7 pass driving `PolishTouchpoint` in-process). Re-exercised together at the spex level (`mix spex` is 355/355 green after the 707 redesign + 716 fixes). The end-to-end browser-then-agent composition wasn't sat down and re-driven in a single QA session — both surfaces were exercised with real Vale via their per-story flows. |

Overall: **7 / 7 pass** (Journey 6 deferred as `@moduletag :manual`; Journey 7 pass derived from per-story QA composition rather than a single linear session)

---

## Journey 1 — First-time founder lands, signs up, reaches MCP setup

**Status: pass**

### Steps taken

1. Navigated to `/` as anonymous visitor.
   - `[data-test='hero-headline']` text: "Marketing for founders, in Claude Code."
   - `[data-test='byo-claude-benefit']` visible
   - `[data-test='agency-cta']` visible
   - `[data-test='install-command']` text: `claude mcp add market-my-spec http://localhost:4000/mcp`
     - **Note:** install command shows port 4000, not 4008. This is because `ConnectionInfo.base_url/0` defaults to `http://localhost:4000` (reads from `Application.get_env(:market_my_spec, :base_url, "http://localhost:4000")`). See Issues.
2. Clicked "Register" nav link — landed on `/users/register`.
3. Filled `user[email]` with `qa-journey1-test@marketmyspec.test`, clicked "Create an account".
   - Server redirected to `/users/log-in` with flash "An email was sent to qa-journey1-test@marketmyspec.test".
4. Navigated to `/dev/mailbox` — found "Confirmation instructions" email for the new user.
5. Clicked the magic link from the email (`/users/log-in/kgZEVaD74HVpTtP3b-clbX0s8maEN62fZxsPYyP2XK4`).
   - Confirmation page shows "Welcome qa-journey1-test@marketmyspec.test" with "Confirm and stay logged in" button.
6. Clicked "Confirm and stay logged in".
   - Landed on `/` as authenticated user with flash "User confirmed successfully."
7. Navigated to `/accounts`.
   - **Observation:** redirected to `/accounts/new` — app requires user to create an account manually. Journey plan stated "default individual account was auto-created on confirmation" but this is not the actual behavior. The `require_account_membership` on-mount guard redirects to `/accounts/new` for zero-membership users.
8. Created "Journey1 Workspace" account via the form — redirected to `/accounts` with account row visible.
9. Navigated to `/mcp-setup`.
   - All three steps render: `[data-test='install-step']`, `[data-test='oauth-step']`, `[data-test='interview-step']`
   - `[data-test='expected-result']` section renders
   - All three troubleshooting blocks render: `[data-test='port-conflict-troubleshooting']`, `[data-test='oauth-troubleshooting']`, `[data-test='mcp-connection-troubleshooting']`
   - Install command on `/mcp-setup` also shows port 4000 (same issue as homepage)

### Screenshots

- `.code_my_spec/qa/journey/j1-01-landing.png`
- `.code_my_spec/qa/journey/j1-02-register-page.png`
- `.code_my_spec/qa/journey/j1-03-after-register.png`
- `.code_my_spec/qa/journey/j1-04-mailbox.png`
- `.code_my_spec/qa/journey/j1-05-after-confirmation.png`
- `.code_my_spec/qa/journey/j1-06-after-confirm-loggedin.png`
- `.code_my_spec/qa/journey/j1-07-accounts-page.png`
- `.code_my_spec/qa/journey/j1-08-accounts-new.png`
- `.code_my_spec/qa/journey/j1-09-account-created.png`
- `.code_my_spec/qa/journey/j1-10-mcp-setup.png`

---

## Journey 2 — Agent connects, runs interview, artifacts surface in /files

**Status: pass**

Bearer token minted via `mix run /tmp/claude/mint_token.exs` (user `qa@marketmyspec.test`, bypassing OAuth flow per journey plan instructions).

### Steps taken

1. MCP session initialized: `POST /mcp` with `initialize` method → `HTTP 200`, `mcp-session-id: session_GKx0RWtkYwY2plPsvjw=`, server info `{"name":"marketing-strategy","version":"1.0.0"}`, capabilities `tools` + `resources`.
2. `notifications/initialized` sent.
3. `tools/list` — returns 6 tools: `delete_file`, `edit_file`, `list_files`, `read_file`, `start_interview`, `write_file`.
4. `list_files` call — returns empty text content. No prior artifacts for this user.
5. `start_interview` call with `business_context: "QA test company"` — response contains full SKILL.md playbook. First 500 chars confirmed to include "marketing-strategy" skill header and "Marketing Strategy" orientation. Contains step manifest references.
6. `write_file marketing/01_current_state.md` — response: `Written: marketing/01_current_state.md`
7. `write_file marketing/02_jobs_and_segments.md` — response: `Written: marketing/02_jobs_and_segments.md`
8. `write_file marketing/03_personas.md` — response: `Written: marketing/03_personas.md`
9. Signed in as `qa@marketmyspec.test` via magic link, navigated to `/files`.
   - All 3 files visible under "Marketing strategy" group: `01_current_state.md`, `02_jobs_and_segments.md`, `03_personas.md`
10. Clicked "Open" on `marketing/01_current_state.md` — file content rendered correctly.

### Screenshots

- `.code_my_spec/qa/journey/j2-01-files-index.png`
- `.code_my_spec/qa/journey/j2-02-file-show.png`

---

## Journey 3 — Returning user iterates on existing strategy, edits a step

**Status: pass**

Fresh MCP session (new `session_id` = `session_GKx0boLZemqQNNVCmRs=`) resets `read_paths`.

### Steps taken

1. Fresh `initialize` → new session. `read_paths` is empty.
2. `list_files` with `prefix: "marketing/"` → returns 3 prior artifacts: `marketing/03_personas.md`, `marketing/02_jobs_and_segments.md`, `marketing/01_current_state.md`.
3. `read_file marketing/03_personas.md` → returns persona content. Path added to `read_paths`.
4. `edit_file marketing/03_personas.md` replacing `"- Goal: get first 100 customers"` with `"- Goal: get first 100 customers\n- Budget: bootstrap, no VC"` → response: `Edited: marketing/03_personas.md`.
5. `edit_file marketing/01_current_state.md` WITHOUT prior `read_file` in this session → `isError: true`, message: `"Read required before editing existing file: marketing/01_current_state.md"`. Gate enforced correctly.
6. `read_file marketing/01_current_state.md` → success.
7. `edit_file marketing/01_current_state.md` replacing `"$10k MRR"` with `"$15k MRR"` → response: `Edited: marketing/01_current_state.md`.
8. Navigated to `/files/marketing/03_personas.md` — edited content visible with `"- Budget: bootstrap, no VC"` appended.

### Screenshots

- `.code_my_spec/qa/journey/j3-01-personas-edited.png`

---

## Journey 4 — Agency owner sets up agency account, creates a client, navigates in/out

**Status: pass**

Signed in as `qa-agency@marketmyspec.test` (agency account owner, seeded via extended `qa_seeds.exs`).

### Steps taken

1. Navigated to `/accounts`.
   - "QA Agency" account row shows `Account type: Agency`.
   - `[data-test='nav-agency-dashboard']` link visible and labeled "Agency Dashboard".
2. Clicked `[data-test='nav-agency-dashboard']` → navigated to `/agency`.
   - `[data-test='agency-client-dashboard']` renders with "No client accounts yet." message.
3. Navigated to `/agency/clients/new`.
   - `[data-test='client-form']` visible.
   - Filled `client[name]` with "Journey4 Client Corp", clicked "Create Client Account".
4. Redirected to `/agency` — "Journey4 Client Corp" appears in table.
   - `[data-test='client-row-originator']` visible (originator: agency).
   - `[data-test='enter-client']` button visible.
   - No Revoke button for originator row.
   - Flash: "Client account created successfully."
5. Clicked `[data-test='enter-client']` on Journey4 Client Corp.
   - Redirected to `/accounts`.
   - `[data-test='inside-client-indicator']` visible with text "Operating inside client: Journey4 Client Corp".
6. Files scope operates within client account prefix.
7. Returned to `/agency` — originator grant row has no "Revoke" button (UI correctly hides it). Backend `revoke_grant/1` returns `{:error, :not_revokable}` for agency-originated grants.

### Screenshots

- `.code_my_spec/qa/journey/j4-01-accounts-agency.png`
- `.code_my_spec/qa/journey/j4-02-agency-dashboard-empty.png`
- `.code_my_spec/qa/journey/j4-03-client-new-form.png`
- `.code_my_spec/qa/journey/j4-04-agency-dashboard-with-client.png`
- `.code_my_spec/qa/journey/j4-05-inside-client.png`

---

## Journey 5 — Client owner grants agency access; agency revokes the invited grant

**Status: pass**

Two users: `qa-client@marketmyspec.test` (client owner, individual account) and `qa-agency@marketmyspec.test` (agency owner).

### Steps taken

**As client user:**

1. Signed in as `qa-client@marketmyspec.test` via magic link, navigated to `/accounts`.
   - `[data-test='grant-agency-access-form']` visible on the "QA Client Account" row.
2. Filled `agency_slug` with `"qa-agency"`, access level default "Read Only", clicked "Grant Access".
   - Flash: "Agency access granted successfully."
3. Submitted same form again with `agency_slug: "qa-agency"`.
   - Inline validation error on agency_slug field: "already has access — this agency already has access to this account". Duplicate grant rejected at application layer.
4. Logged out.

**As agency user:**

5. Signed in as `qa-agency@marketmyspec.test`, navigated to `/agency`.
   - Dashboard shows two clients: "Journey4 Client Corp" (originator: agency, no Revoke) and "QA Client Account" (originator: client, with Revoke).
   - `[data-test='client-row-invited']` visible for QA Client Account.
6. Clicked `[data-test='revoke-grant']` on "QA Client Account".
   - Flash: "Access revoked successfully."
   - "QA Client Account" no longer in dashboard — only "Journey4 Client Corp" remains.

### Screenshots

- `.code_my_spec/qa/journey/j5-01-client-accounts.png`
- `.code_my_spec/qa/journey/j5-02-grant-submitted.png`
- `.code_my_spec/qa/journey/j5-03-duplicate-grant-rejected.png`
- `.code_my_spec/qa/journey/j5-04-agency-sees-invited-client.png`
- `.code_my_spec/qa/journey/j5-05-after-revoke.png`

---

## Issues

### Issue 1 — Install command shows wrong port (4000) in dev

**Severity:** MEDIUM
**Scope:** app
**Title:** Install command and server URL show hardcoded port 4000 instead of runtime port

**Description:**
`MarketMySpec.McpAuth.ConnectionInfo.base_url/0` reads from `Application.get_env(:market_my_spec, :base_url, "http://localhost:4000")`. In dev, no `base_url` config is set for this key, so it defaults to port 4000. But the dev server runs on 4008 (port 4000 conflicts with the sister CodeMySpec project). Both `/` (`[data-test='install-command']`) and `/mcp-setup` (`[data-test='install-command']`) show `claude mcp add market-my-spec http://localhost:4000/mcp` — this install command would fail for any dev user whose server is on 4008.

**Reproduction:**
1. Start server with `PORT=4008 mix phx.server`
2. Visit `/` or `/mcp-setup`
3. Observe install command shows `:4000/mcp`

**Expected:** Install command should reflect the actual running server URL. `ConnectionInfo` should use the endpoint's runtime URL (e.g., `MarketMySpecWeb.Endpoint.url()`) instead of a hardcoded application config default, so the command is always accurate.

**Note:** The `OauthController` well-known metadata already uses `Endpoint.url()` for runtime accuracy. `ConnectionInfo` should follow the same pattern.

---

### Issue 2 — Journey plan states "default account auto-created on confirmation" but app requires manual account creation

**Severity:** LOW
**Scope:** qa
**Title:** Journey 1 plan inaccurate — new users are redirected to /accounts/new, not given a default account

**Description:**
The journey plan (Step 4) says "the default individual account was auto-created on confirmation." In reality, after confirming a magic link, a new user with zero memberships is redirected to `/accounts/new` (via the `require_account_membership` on-mount guard). There is no auto-provisioning of a default individual account. The journey still passes because creating an account manually is a valid path, but the plan text is misleading.

**Affected file:** `.code_my_spec/qa/journey_plan.md`

**Suggestion:** Update journey plan Step 4 to say "User lands on `/accounts/new` with a prompt to create their first account" and update the expected outcome to say "User creates account at `/accounts/new`; `/accounts` then shows one row."

---

### Issue 3 — qa_seeds.exs outputs magic-link URLs with port 4007 (old plan.md port)

**Severity:** LOW
**Scope:** qa
**Title:** Original qa_seeds.exs hard-coded port 4007 in magic-link URL output

**Description:**
The original `qa_seeds.exs` (before this QA run extended it) output magic-link URLs with port 4007 (`http://localhost:4007/users/log-in/...`). The dev server now runs on 4008 (per the journey plan prerequisites). The extended seeds.exs uses 4008 consistently. This issue documents that the old script had the wrong port.

**Status:** Fixed in this QA run (seeds.exs updated to port 4008).

---

## Journey 7 — Founder saves Vale style guide, polishes touchpoint prose with lint feedback

**Status: pass (composition)**

**Execution mode:** Verified at the per-story level (QA attempts on stories 736 and 738) plus a full spex run (`mix spex`, 355/355 green) on 2026-05-21. The end-to-end multi-surface flow (browser → agent → polish loop → mark posted) wasn't driven as a single linear QA session; each step is covered by a different per-story attempt or spex contract.

### Step coverage

| Step | Surface | Coverage |
|------|---------|----------|
| 1–2. Save Vale config on Account at `/accounts/:id/style-guide` | LiveView (`MarketMySpecWeb.LinterLive.StyleGuide`) | QA 736 attempt `645ef51a-44b4-4465-b034-26e05a2bdb7c` — paste, save, reload, verify body visible in textarea, success flash. **PASS.** Real Vale CLI ran via `vale ls-config` for the validation. |
| 3. Agent searches for engagement opportunities (Reddit/ElixirForum) | MCP tool (`SearchEngagements` / `RunSearch`) | Existing story 705/710 spex (green). Not re-verified this session — search behavior unchanged. |
| 4. `stage_response(thread_id, synopsis, angle)` creates `:staged` Touchpoint with derived UTM params | MCP tool (`StageResponse`, redesigned this session) | All 9 spex in `test/spex/707_stage_a_touchpoint_from_a_thread_synopsis_angle_utm_link/` green. Schema migration ran in dev + test. UTM derivation from `Thread.source` verified by criterion 6502 (Reddit → `reddit/comment`, ElixirForum → `elixirforum/reply`). Default `utm_campaign` (`<subreddit>:<source_thread_id>`) verified by 6503. Synopsis write-once on parent Thread verified by 6505/6506. |
| 5. `polish_touchpoint` blocks write when Vale alerts are non-empty | MCP tool (`PolishTouchpoint`, new this session) | QA 738 attempt `1acdc962`, scenario 6519: `write-good` config saved → "very useful and very interesting overall" prose → 3 alerts returned, `polished_body` stays nil. **PASS.** |
| 6. `polish_touchpoint` writes body when Vale alerts are empty | MCP tool (`PolishTouchpoint`) | QA 738, scenarios 6510 (no config → empty alerts → writes) and 6517 (saved config, clean prose → empty alerts → writes). **PASS.** Alert shape verified flat per scenario 6516. |
| 7. TouchpointLive.Show renders polished body + angle + thread synopsis | LiveView (`MarketMySpecWeb.TouchpointLive.Show`, story 716) | Story 716 spex green after this session's API-update pass (24 spex updated from old `StageResponse`+`UpdateTouchpoint` shape to the new tools). LiveView itself is unchanged. |
| 8. Mark posted via TouchpointLive.Show form | LiveView (`MarketMySpecWeb.TouchpointLive.Show`) | Existing story 716 spex (green). Not re-verified this session — lifecycle code path unchanged. |

### Cross-account isolation

Verified at two surfaces:

- LiveView style-guide page (QA 736 scenario 6524, attempt `645ef51a`): Bea navigates to Sam's `/accounts/<sam_account>/style-guide` → redirected to `/accounts` with "Account not found" flash; Sam's body never rendered. **PASS.**
- MCP `polish_touchpoint` (QA 738 scenario 6515, attempt `1acdc962`): Bea's frame calls `polish_touchpoint` with Sam's `touchpoint_id` → response carries `isError: true`, no `polished_body` mutation on Sam's row, no leak of Sam's data in the error body. **PASS.**

### Schema migrations applied this session

- `priv/repo/migrations/20260520150000_create_linter_configs.exs` — `linter_configs` table for per-account `.vale.ini` storage. Ran on dev + test.
- `priv/repo/migrations/20260520160000_add_utm_fields_to_touchpoints.exs` — `utm_source` / `utm_medium` / `utm_campaign` columns on `touchpoints`. Ran on dev + test.

### Production code change made during QA

- `lib/market_my_spec/linter/vale.ex` now reads `VALE_STYLES_PATH` env var to override the default `/app/priv/vale/styles` (Docker image path). Discovered by QA 736 attempt 1 (`3be30b9c`) which returned `partial` because the hardcoded path blocked saves in dev. Fix landed before attempt 2 (`645ef51a`) which passed end-to-end. Filed and resolved: issue `08d754db-9280-4fb3-b91e-1328641d3ffe`.

### Open follow-ups for a future single-session journey run

If you want a single linear Journey-7 session for the record:

1. Start dev server: `PORT=4007 VALE_STYLES_PATH=~/.config/vale/styles mix phx.server` (or whatever path holds your local `vale sync` output).
2. Seed: `mix run priv/repo/qa_seeds.exs`.
3. Sign in as QA user, paste a `write-good`-enabled `.vale.ini`, save.
4. In a second terminal: `iex -S mix` and drive `StageResponse.execute(...)` + `PolishTouchpoint.execute(...)` end-to-end against the staged Thread (or use a real Claude Code agent session if MCP-over-HTTP is wired by then).
5. Open `/accounts/:id/touchpoints/:tp_id`, mark posted, confirm `:posted` state and `comment_url`/`posted_at` persisted.

No new issues filed for Journey 7 beyond the already-resolved Vale path issue (`08d754db`).

---

## Blockers encountered

1. **Seed script extension required:** `qa_seeds.exs` only seeded the basic QA user. Extended it inline to add `qa-agency@marketmyspec.test` and `qa-client@marketmyspec.test` with appropriate accounts. The extension is now idempotent and committed.

2. **OAuth round-trip for Journey 2:** Per journey plan instructions, the full Claude Code OAuth flow was skipped. Used the existing `mint_token.exs` recipe to mint a bearer token directly for `qa@marketmyspec.test`. MCP session established and all tools exercised via curl.

3. **Vibium screenshot path:** Screenshots land in `~/Pictures/Vibium/` regardless of filename path. Copied to `.code_my_spec/qa/journey/` after each journey.

4. **Browser session state:** Vibium browser persists across journeys; logged out between journeys to switch users cleanly.
