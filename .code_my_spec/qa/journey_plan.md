# Qa Journey Plan

End-to-end QA journey plan for MarketMySpec. Seven journeys covering the 19 in-flight stories. Each journey traces a real user path across multiple stories, not a single criterion.

## Journeys

### Journey 1 — First-time founder lands, signs up, reaches MCP setup

**Role:** Anonymous visitor → confirmed user with one default individual account.

**Stories covered:** 633 (Public Landing Page), 609 (Magic Link Sign-In), 678 (Multi-Tenant Accounts default account), 611 (View MCP Connection Instructions), 634 (MCP Setup Guide).

**Steps:**
1. Anonymous visitor opens `/` and sees the public landing page with the canonical headline "Marketing for founders, in Claude Code", the BYO-Claude benefit, the install command (`claude mcp add market-my-spec ...`), and an agency CTA below.
2. Visitor clicks Sign up, lands on `/users/register`, enters an email, submits.
3. Server sends a magic-link email; visitor opens `/dev/mailbox`, finds the link, clicks it.
4. Confirmation flow lands the user in an authenticated session; the default individual account was auto-created on confirmation.
5. User navigates to `/mcp-setup`. The page renders the three steps (install / oauth / interview) with `data-test` selectors, an expected-result section, and three troubleshooting blocks.
6. User copies the install command shown on the page; it includes the full server URL.

**Expected outcome:**
- Default account exists (`/accounts` shows one row).
- `/mcp-setup` returns 200 with all required `data-test` attributes.
- The install command on `/mcp-setup` matches `MarketMySpec.McpAuth.ConnectionInfo.install_command/0` output.

---

### Journey 2 — Agent connects, runs the marketing-strategy interview, artifacts surface in /files

**Role:** Authenticated user with MCP connected via the OAuth + PKCE flow; the agent (Claude Code) is the actor for steps 4–7.

**Stories covered:** 612 (OAuth for MCP), 674 (Marketing Strategy Interview), 675 (Skill Over MCP / SSE), 676 (Strategy Artifacts Saved), 683 (Agent File Tools Over MCP).

**Steps:**
1. User runs `claude mcp add market-my-spec http://localhost:4007/mcp`. The OAuth flow opens `/oauth/authorize`; user signs in (existing session) and approves.
2. Claude Code receives a bearer token via `/oauth/token` and stores it. MCP session establishes via `POST /mcp` initialize → SSE response with server info.
3. Agent calls `list_files` (empty result) and reads `marketing-strategy://orientation` to load SKILL.md.
4. Agent calls `start_interview`, gets back the orientation + step manifest.
5. Agent works through steps 1–3, calling `read_file` on `marketing-strategy://steps/01_current_state` etc. After each step the agent calls `write_file` with `marketing/01_current_state.md`, `marketing/02_jobs_and_segments.md`, `marketing/03_personas.md`.
6. User opens `/files` in the browser. All three artifacts appear under the active account's prefix.
7. User clicks `/files/marketing/01_current_state.md` and reads the rendered content.

**Expected outcome:**
- OAuth round-trip lands a bearer token in Claude Code.
- `start_interview` returns the SKILL.md orientation (verifiable by the substring "Marketing Strategy" appearing in the response).
- After step 3 the user has 3 artifacts visible in `/files` and readable in `/files/*key`.
- All three writes succeed without ever calling `read_file` on the new paths first (gate only fires on overwrite of existing paths).

---

### Journey 3 — Returning user iterates on existing strategy, edits a step

**Role:** Authenticated user who completed Journey 2 in a prior session; agent re-enters with prior artifacts on disk.

**Stories covered:** 674 iteration mode, 676 artifact persistence across sessions, 683 (edit_file with read-before-edit gate).

**Steps:**
1. User opens a fresh Claude Code session (or runs `start_interview` again) so `frame.assigns.read_paths` resets.
2. Agent calls `list_files` with `prefix: "marketing/"` and finds the 3 prior artifacts.
3. Agent calls `read_file` on `marketing/03_personas.md`. Read succeeds; path is added to `read_paths`.
4. Agent calls `edit_file` on `marketing/03_personas.md` with a precise `old_string` → `new_string` replacement. Edit succeeds (gate satisfied).
5. Agent attempts `edit_file` on `marketing/01_current_state.md` without reading it first in this session. Tool returns "Read required before overwriting" error.
6. Agent reads `marketing/01_current_state.md`, then retries the edit; succeeds.
7. User opens `/files/marketing/03_personas.md` and verifies the edit applied.

**Expected outcome:**
- `list_files` returns 3 entries from the prior session's writes.
- `edit_file` without prior `read_file` on existing path returns the read-required error.
- `edit_file` after `read_file` succeeds and the change is reflected in `/files`.

---

### Journey 4 — Agency owner sets up agency account, creates a client, navigates in/out

**Role:** User whose account was admin-provisioned with `type: :agency`.

**Stories covered:** 679 (Agency Account Type And Client Dashboard), 678 (account-type field, scope switching).

**Steps:**
1. Agency user signs in. The nav shows the `[data-test='nav-agency-dashboard']` link (only rendered for `current_scope.active_account.type == :agency`).
2. User clicks the agency dashboard link, lands on `/agency`. Empty client list initially.
3. User navigates to `/agency/clients/new`, fills out the client account form (`[data-test='client-form']`), submits.
4. New individual client account is created; an originator-status `AgencyClientGrant` links the agency to the new client. The dashboard now shows one client row with `[data-test='client-row-originator']`.
5. User clicks `[data-test='enter-client']` on the row. Active scope switches to the client account; user lands at `/accounts` with `[data-test='inside-client-indicator']` rendered.
6. User uses `read_file`/`write_file` (or just navigates `/files`) — operations now happen against the client account's prefix, not the agency's.
7. User attempts to revoke the originator grant from the dashboard — operation is rejected (originator grants can't be revoked, criterion 5784).
8. User exits client context (back to `/agency`).

**Expected outcome:**
- Agency-only nav link visible.
- Client creation produces both an Account and a grant in one transaction.
- Active-client switching is reflected on `/accounts` via the inside-client indicator and on the file scope.
- Originator-grant revocation is blocked.

---

### Journey 5 — Client owner grants agency access; agency revokes the invited grant

**Role:** Two users — a client owner with an individual account, and an agency owner with an agency account.

**Stories covered:** 679 (invited-access flow + revocation, criteria 5785, 5786, 5790), 678.

**Steps:**
1. Client owner signs in, lands on `/accounts`, sees the `[data-test='grant-agency-access-form']`.
2. Client owner enters the agency's slug and an access level, submits. A pending `AgencyClientGrant` is created with originator `client`, status `pending`.
3. Client attempts to grant access to the same agency a second time — server rejects (criterion 5790, unique constraint on agency_id + client_id).
4. Agency owner signs in, navigates to `/agency`. The client appears with `[data-test='client-row-invited']`.
5. Agency owner clicks `[data-test='revoke-grant']` on the invited row. Grant transitions to revoked.
6. Agency dashboard re-renders without the revoked client.

**Expected outcome:**
- Grant form on `/accounts` is visible to client account owners.
- Duplicate grants for the same agency-client pair are rejected.
- Invited grants can be revoked by either party.
- Revoked clients don't appear on the dashboard.

### Journey 6 — Founder installs the MMS Agent, pairs, joins channel, dispatches Reddit search

**Role:** Founder with an existing MMS account, installing the local agent binary on their machine.

**Stories covered:** 731 (Install and pair), 732 (Connect and report status), 733 (Reddit operations via agent).

**Steps:**
1. User signs in to `https://marketmyspec.com` (or `http://localhost:4007` in dev). User opens `/agents` — empty list, no agents paired.
2. User installs the binary: `brew tap Code-My-Spec/mms-agent && brew install mms-agent`. (On a fresh Apple Silicon Mac; if already installed, skip.)
3. User runs `mms-agent pair`. The default browser opens to `/agents/pair?state=…&port=…&name=…`. User clicks **Approve**.
4. The binary's loopback callback receives the token + `agent_id` + `user_id`; persists to `~/.mms-agent/auth.json` at mode 0600; prints `mms-agent: paired. Token saved to ~/.mms-agent/auth.json.` and exits 0.
5. User runs `mms-agent server`. `MarketMySpecAgent.Channel.Client` reads the creds, connects via `wss://<server>/agent/websocket?vsn=2.0.0` (or `ws://localhost:4007/...` in dev), joins `agents:<user_id>`. Expect log lines `[Agent.Channel.Client] connected — joining agents:N` then `[Agent.Channel.Client] joined agents:N`.
6. User refreshes (or just watches) `/agents` — the paired agent shows `Online · v0.1.0 · last seen <ts>` via the `Phoenix.Presence` diff. No manual refresh required after the LiveView mounts.
7. (Story 733 happy path) User invokes the `SearchEngagements` MCP tool. Server's `MarketMySpec.Agents.Dispatcher.dispatch_http/3` broadcasts on the user's topic; the binary's `Channel.Client` executes the request via `Req` (gated by `MarketMySpecAgent.HostAllowlist`), pushes the response back. The tool returns real Reddit candidates with **no** anonymous-fallback `notices` entry.
8. User kills the binary (`pkill -f market_my_spec_agent` or Ctrl-C in the `mms-agent server` terminal). `/agents` flips to `Offline` within ~5s via the `presence_diff` broadcast.
9. (Story 733 negative path) User invokes `SearchEngagements` again with no online agent. The tool returns a `notices` array containing `"No online MMS Agent … Pair or start an agent at /agents …"` plus anonymous-fallback Reddit candidates (lower fidelity, but non-empty).

**Expected outcome:**
- Binary installs cleanly via Homebrew on Apple Silicon.
- Pair flow completes; `~/.mms-agent/auth.json` exists at mode 0600 with `agent_id`, `user_id`, `token`, `server_url`, `paired_at`.
- Channel joins via real WSS (prod) or WS (dev) to the configured `server_url`.
- `/agents` flips Online ↔ Offline without manual refresh (presence-driven).
- Reddit search dispatches through the agent when online; falls back with a user-facing `notices` entry when offline.

---

### Journey 7 — Founder saves a Vale style guide, polishes touchpoint prose with lint feedback

**Role:** Authenticated founder with the engagement-finder flow already set up; agent (Claude Code) is the actor for steps 3–6.

**Stories covered:** 736 (Paste a Vale configuration onto my account), 707 (Stage a Touchpoint from a Thread — synopsis, angle, UTM link), 738 (Polish touchpoint prose with Vale lint feedback).

**Steps:**
1. Founder signs in and navigates to `/accounts/:account_id/style-guide`. The empty-state intro reads "No configuration saved yet."
2. Founder pastes a valid `.vale.ini` body that activates `write-good` (e.g. `[*.md] BasedOnStyles = write-good`) and clicks **Save**. The page re-renders with the saved body in the textarea, a success flash, and the "Clear configuration" button visible.
3. Agent calls `search_engagements` (or `run_search`) to find a Reddit/ElixirForum thread of interest. Returns a Thread UUID.
4. Agent calls `stage_response(thread_id, synopsis, angle)` — the new 707 signature. The tool persists `synopsis` on the parent Thread (write-once), creates a `:staged` Touchpoint carrying the angle and the derived UTM params (`utm_source=reddit`/`utm_medium=comment`/`utm_campaign=<subreddit>:<source_thread_id>` for Reddit; `utm_source=elixirforum`/`utm_medium=reply`/`utm_campaign=<category-slug>:<source_thread_id>` for ElixirForum). Returns the new Touchpoint id.
5. Agent dictates and refines prose with the founder, then calls `polish_touchpoint(touchpoint_id, polished_body)` with prose that contains a weasel word (e.g. "very"). The tool runs Vale against the founder's saved configuration; alerts come back non-empty; the polished body is NOT persisted; the response shape is `%{"touchpoint" => %{...polished_body: nil...}, "alerts" => [%{severity, check, line, column, message}, ...]}`. The agent reads the alerts and revises the prose.
6. Agent re-calls `polish_touchpoint` with the revised prose (no weasel words). Alerts come back empty; `polished_body` is persisted on the Touchpoint; the response carries the updated Touchpoint and `alerts: []`.
7. Founder opens `/accounts/:account_id/touchpoints/:touchpoint_id` (story 716's TouchpointLive.Show). The polished body is visible alongside the angle, the parent Thread synopsis, and the UTM params on the row.
8. Founder copies the polished body, posts it as a reply on the source platform, returns to TouchpointLive.Show, pastes the live comment URL into the "mark posted" form, submits. Touchpoint transitions to `:posted` with `comment_url` and `posted_at` populated (story 716).

**Expected outcome:**
- Vale config persists on the Account; reloading `/accounts/:account_id/style-guide` shows the saved body.
- `stage_response` rejects calls without required `synopsis` and `angle`; never accepts `polished_body` or `link_target` (those parameters no longer exist on its schema).
- `polish_touchpoint` is the only MCP tool that writes `polished_body`. `update_touchpoint` no longer accepts `polished_body` at all.
- Lint feedback is blocking: alerts non-empty → no write; alerts empty → write. The agent iterates without the founder reading lint output.
- Cross-account access on either `polish_touchpoint` or the style-guide URL returns `:not_found` / redirects with no data leak.

**Cross-account isolation check (optional sub-flow):** Sign in as a second founder, navigate to the first founder's `/accounts/<other-account-id>/style-guide` URL — redirects to `/accounts` with "Account not found" flash. The first founder's saved body never renders for the second.

---

## Prerequisites

- Phoenix dev server running on port 4007: `PORT=4007 mix phx.server` (or `just server`). (Port 4000 conflicts with the sister `code_my_spec` project; `envs/dev.env` sets `PORT=4007` but `mix phx.server` doesn't always pick it up — see `reference_dev_server.md` and the dotenvy note in `.code_my_spec/qa/plan.md`.)
- Database migrated: `mix ecto.migrate`
- Files backend in dev = `MarketMySpec.Files.Disk` (writes under `tmp/files/`, no AWS creds needed). Set in `config/dev.exs`.
- OAuth credentials present in `envs/dev.env` (loaded via Dotenvy in `config/runtime.exs`): `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `RESEND_API_KEY`, `CLOAK_KEY`. These must be present even though Journeys 1–5 don't go through Google/GitHub sign-in — the Endpoint init reads them.
- Seed data: at minimum, two test users (one individual, one agency-account-owner) and one agency account. Use `priv/repo/qa_seeds.exs` as the entrypoint; extend if it doesn't already create the agency seed.
- For Journey 2, Claude Code must be available as the MCP client. Add via `claude mcp add market-my-spec http://localhost:4007/mcp`. The OAuth approval is interactive (browser).
- For curl-only fallbacks (when browser-mediated OAuth isn't available), mint a bearer token directly via `mix run /tmp/claude/mint_token.exs` (recipe in `reference_mcp_architecture.md`). This skips the user-mediated consent step but exercises the same MCP surface.
- Vibium MCP browser tools are wired and verified working as of this session — use them for browser-driven steps.
- For Journey 6: Apple Silicon Mac (linux/intel targets deferred — see `docs/release.md` and `.github/workflows/release.yml`). Xcode 26+ Command Line Tools must be current or Homebrew installs fail. `aws sso login` only needed if testing against prod via `scripts/deploy`; pair-only QA doesn't need AWS creds.
- For Journey 6 in-tree (no Burrito binary): `just agent` boots the agent in `MIX_ENV=dev_agent` against `http://localhost:4007`. See `.code_my_spec/qa/plan.md` § "`just agent`" for the full bring-up.
- For Journey 7: Vale CLI installed locally (`brew install vale` on macOS; download from GitHub Releases in Docker per `.code_my_spec/knowledge/vale-cli.md`). `VALE_STYLES_PATH` env var must point at the vendored styles tree (defaults to `/app/priv/vale/styles` for the Docker image; in local dev set it to e.g. `~/.config/vale/styles` or wherever `vale sync` landed the packages). `envs/dev.env` should export `VALE_STYLES_PATH`. `write-good` must be present in the styles tree for the weasel-word assertion in step 5 — run `vale sync` from a directory with a `.vale.ini` referencing `Packages = write-good` if it's not there yet.

## Notes

- Stories 672 (Google sign-in) and 673 (GitHub sign-in) are intentionally NOT in any journey. End-to-end Google/GitHub journeys require live OAuth providers and browser automation that survives third-party redirects, which Vibium can't reliably do without a stubbed identity provider. The button-presence check on `/users/log-in` is covered by per-story spex; the redirect-and-callback half of those flows is best left to manual smoke tests when live creds are configured.
- Journey 2 step 1 (Claude Code OAuth flow) is the trickiest to automate. Vibium can drive the browser through `/oauth/authorize`, but the post-approval token-exchange happens in Claude Code's process, not the browser. For Phase 2 execution, treat the OAuth establishment as a manual prerequisite: the QA agent assumes a bearer token is already minted (via `mint_token.exs`) and starts the journey at the MCP-session-establishment step.
- The read-before-overwrite gate is per-Anubis-session. Journey 3's "fresh session" precondition matters — restarting Claude Code or running a separate curl session both reset `frame.assigns.read_paths`.
- Journey 4 needs an admin-provisioned agency account (self-service produces only individual accounts, criterion 5777). Create the agency via the seed script using `MarketMySpec.Accounts.AccountsRepository.create_agency_account_with_owner/2`.
- Phase 3 Wallaby tests should pin the bearer-token-minting step (Journey 2 prereq) to a fixture rather than driving the OAuth flow — Wallaby on its own can't span the Phoenix server + a separate Claude Code process.
- Journey 6 is a 3-process flow (browser + `mms-agent` binary + Phoenix server). Wallaby can't drive the binary side cleanly, so the corresponding test (`test/e2e/journey_6_agent_pair_test.exs`) is tagged `@moduletag :manual` and documents the manual procedure in its `@moduledoc`. The browser-side surface (`/agents` rendering an Online agent + flipping to Offline on presence diff) can be exercised by pre-seeding an `Agent` record and a `Phoenix.Presence` track in a future test; the binary-side pair flow and Reddit dispatch round-trip stay manual until we have a fixture process that can stand in for the burrito binary. Per-story BDD spex (`test/spex/{731,732,733}_*/`) cover the pieces in isolation: Channel.Client uses `Phoenix.ChannelTest` with a real join, Dispatcher tests run against a real `AgentChannel` join, pairing tests exercise the LiveView + token persistence.
- Journey 7 spans the LiveView (style-guide settings page) and the MCP-tool surface (`stage_response`, `polish_touchpoint`). The browser half is driven by Vibium; the MCP half is driven in-process via `mix run -e` with a synthesized `Anubis.Server.Frame` (no MCP-over-HTTP transport is wired yet in this project — see `.code_my_spec/qa/plan.md`). The Vale lint is the operative gate: in dev/QA the real `vale` binary runs against the saved `.vale.ini`; in `MIX_ENV=test` the spex use `MarketMySpec.Linter.TestStub` which flags occurrences of "very" when the saved config enables `write-good`. Per-story BDD spex (`test/spex/{736,738}_*/` and the redesigned `test/spex/707_stage_a_touchpoint_from_a_thread_synopsis_angle_utm_link/`) cover the pieces in isolation.
