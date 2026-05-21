# Prompt: Bring `.code_my_spec/qa/journey_plan.md` up to date

## Goal

Two changes:

1. **Add a Journey 6 (MMS Agent install → pair → channel → Reddit dispatch).** Stories 731, 732, 733 were shipped on 2026-05-20 and aren't represented in any journey yet.
2. **Reconcile the port number.** `journey_plan.md` says `PORT=4008` but `.code_my_spec/qa/plan.md` and `config/dev_agent.exs` say `4007`. Pick one (likely 4007 since that's what the running dev server uses), update both files, and update the dotenvy note if needed.

If a corresponding Wallaby test should exist for Journey 6 (see existing `test/e2e/journey_3_iteration_test.exs` for the pattern), draft a sketch — but don't fight the OAuth/browser-mediated bits in Wallaby; agent pairing is a 3-process flow (browser + binary + server) that Wallaby alone can't drive cleanly. A `@moduletag :manual` or a comment block describing how to verify manually is fine.

## What was shipped this session (the missing context)

**Stories 731 / 732 / 733** — the MMS Agent feature:
- 29/29 BDD spex green (`test/spex/{731,732,733}_*/`)
- QA all PASS via `codemyspec:qa` subagents (reports in `.code_my_spec/qa/{731,732,733}/`)
- Server-side: `MarketMySpec.Agents` context, `MarketMySpecWeb.AgentSocket` + `AgentChannel`, `AgentLive.Pair` + `AgentLive.Index`, `AgentVersionController`
- Binary side: `lib/market_my_spec_agent/` (own OTP application via `:dev_agent` / `:prod_agent` envs that swap `mod:`); `MarketMySpecAgent.Pairing`, `Channel.Client`, `VersionCheck`, `CLI`
- Burrito binary distributed via Homebrew tap `Code-My-Spec/homebrew-mms-agent`; CI in `.github/workflows/release.yml`; release docs in `docs/release.md`
- Prod is paired and serving — `mms-agent` installed via `brew install Code-My-Spec/mms-agent/mms-agent` on this machine, `~/.mms-agent/auth.json` mode 0600 contains `agent_id: bf6fbeeb-1c17-41d6-b939-ac8cfaff2d2a`, paired to `https://marketmyspec.com` (user_id 1)

## Suggested Journey 6 shape

**Role:** Founder who already has an MMS account, installing the local agent.

**Stories covered:** 731 (Install and pair), 732 (Connect and report status), 733 (Reddit operations via agent).

**Steps:**
1. User signs in to https://marketmyspec.com (or local dev). User opens `/agents` — empty list.
2. User installs the binary: `brew tap Code-My-Spec/mms-agent && brew install mms-agent`. (On a fresh machine; on this dev box it's already installed.)
3. User runs `mms-agent pair`. Default browser opens to `/agents/pair?state=…&port=…&name=…`. User clicks **Approve**.
4. Binary's loopback callback receives the token + agent_id + user_id; persists to `~/.mms-agent/auth.json` mode 0600; prints `mms-agent: paired. Token saved to ~/.mms-agent/auth.json.` and exits 0.
5. User runs `mms-agent server`. `Channel.Client` reads the creds, connects via `wss://<server>/agent/websocket?vsn=2.0.0`, joins `agents:<user_id>`. (Log lines: `[Agent.Channel.Client] connected — joining agents:N`, then `[Agent.Channel.Client] joined agents:N`.)
6. User refreshes `/agents` — the paired agent shows `Online · v0.1.0 · last seen <ts>` via Phoenix.Presence diff.
7. (Story 733) User triggers a Reddit search via `SearchEngagements` MCP tool. Server's `Dispatcher.dispatch_http/3` broadcasts on the user's topic; binary's `Channel.Client` executes the request via `Req` (gated by `HostAllowlist`), pushes the response back. Tool returns real Reddit candidates with no anonymous-fallback notice.
8. User kills the binary (`pkill -f market_my_spec_agent`). `/agents` flips to `Offline` within ~5s via the presence_diff broadcast.
9. (Story 733 negative path) User triggers another Reddit search with no online agent. Tool returns the `notices` array containing `"No online MMS Agent … Pair or start an agent at /agents …"` plus anonymous-fallback Reddit candidates.

**Expected outcome:**
- Binary installs cleanly via Homebrew.
- Pair flow completes and persists token at mode 0600.
- Channel joins via real WSS to prod (or `ws://localhost:4007` in dev).
- `/agents` Online ↔ Offline flips without page refresh (presence-driven).
- Reddit search dispatches through the agent when online; falls back with a user-facing notice when offline.

**Prerequisites additions for the bottom of journey_plan.md:**
- Apple Silicon Mac for `brew install` (linux/intel targets deferred per release.yml notes)
- Xcode 26+ Command Line Tools current (Homebrew blocks installs otherwise)
- `aws sso login` fresh if testing against prod (the `scripts/deploy` render-env path needs it; not relevant for pair-only tests)

## Implementation notes (things to NOT break)

- Don't add Journey 6 INSIDE another journey — it's its own user flow.
- `journey_plan.md` already calls out that Google/GitHub OAuth journeys (672/673) are excluded from automation. Don't accidentally include them.
- The wallaby test `test/e2e/journey_3_iteration_test.exs` is unrelated to agent work. It should keep passing — verify with `mix test --include wallaby test/e2e/journey_3_iteration_test.exs` after the port reconciliation lands. (The wallaby test doesn't reference a port directly; the FeatureCase handles that. But verify.)
- If you do write a Journey 6 wallaby sketch, model it on `journey_3_iteration_test.exs` (uses `MarketMySpecWeb.FeatureCase, async: false` and Wallaby's `visit` / `click` / `assert_has`). Tag it `@moduletag :manual` if it requires running the binary out-of-process.
- The dev server confusion: `.code_my_spec/qa/plan.md` line 5 says 4007. `journey_plan.md` line 119 says 4008. `config/dev.exs` is the source of truth — check it and update whichever doc is wrong. (As of 2026-05-20 the dev server we used was on 4007.)

## How to verify your changes

1. `mix spex` — must stay 353/353 green.
2. `mix compile --warnings-as-errors` — must stay clean.
3. Re-read `journey_plan.md` end-to-end. The journey count in the doc header (currently "Five journeys covering the 13 in-flight stories") will need updating to "Six journeys covering the 16 in-flight stories" (or whatever the actual numbers shake out to once 731+732+733 are added).
4. If you touch any wallaby test, confirm `mix test --include wallaby` still passes (or document the failure if chromedriver isn't installed locally — that's an env issue, not a test bug).

## What NOT to do

- Don't write fresh BDD spex — they're already done and green.
- Don't re-implement anything. The MMS Agent feature is shipped, in prod, and Homebrew-installable.
- Don't run `just release X.Y.Z` — there's no need to cut a new release for doc updates.
- Don't fight Wallaby's OAuth limitations. Manual smoke-test notes in the markdown are the right answer for Journey 6's binary-side steps.

## References

- `docs/release.md` — how the Homebrew pipeline works
- `.code_my_spec/qa/plan.md` § "`just agent`" — current QA bring-up for the agent in dev (in-tree, not the burrito binary)
- `.code_my_spec/qa/{731,732,733}/brief.md` — what was actually tested per story
- `test/spex/{731,732,733}_*/` — the BDD spex (29 files)
- `lib/market_my_spec_agent/` — binary code
- `lib/market_my_spec/agents/` — server-side context
- `lib/market_my_spec_web/controllers/agent_{channel,version_controller}.ex` — channel + version endpoint
- `lib/market_my_spec_web/live/agent_live/{pair,index}.ex` — pair + agents page LiveViews
