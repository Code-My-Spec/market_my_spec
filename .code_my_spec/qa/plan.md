# MarketMySpec QA Plan

## App Overview

MarketMySpec is a Phoenix 1.8 application running on **port 4007** (dev). It is a multi-tenant SaaS platform for marketing CodeMySpec, featuring:

- **Browser-based auth**: Magic-link tokens + OAuth (Google, GitHub, CodeMySpec)
- **Three account types**: individual, agency, and client
- **Authenticated LiveViews**: journeys, venue management, saved searches, threads, touchpoints, style guides, agent pairing
- **MCP servers**: `/mcp/*` endpoints for engagement orchestration tools + analytics admin (both bearer-authenticated)
- **OAuth metadata**: Public endpoints at `/.well-known/` returning issuer metadata for dev.marketmyspec.com

| Endpoint | Port | Pipeline | Auth |
|----------|------|----------|------|
| HTML/LiveView routes | 4007 | `:browser` | Session (magic-link or OAuth) |
| OAuth endpoints | 4007 | `:api` | Public (token/register/revoke) |
| MCP servers | 4007 | `:mcp_authenticated` | Bearer token |
| `/dev/dashboard` | 4007 | `:browser` | dev-only (no auth) |

## Tools Registry

### Vibium (Browser Automation)

**When to use**: Testing authenticated LiveView routes, forms, navigation, and multi-step workflows (login, account creation, search creation, style guide paste, agent pairing).

**Setup**: Vibium MCP server configured in Claude Code settings. Call MCP tools directly (no CLI binary).

**Example: Login via magic link**
```
browser_navigate(url: "http://localhost:4007/users/log-in")
browser_fill(selector: "input[name='user[email]']", text: "qa@marketmyspec.test")
browser_click(selector: "button[phx-submit='send_magic_link']")
browser_wait_for_text(text: "Check your email")
```

**Example: Login via password form**
```
browser_navigate(url: "http://localhost:4007/users/log-in")
browser_scroll_into_view(selector: "#login_form_password")
browser_fill(selector: "#login_form_password_email", text: "qa@marketmyspec.test")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/accounts")
```

**Common selectors**:
- Magic-link form: `input[name='user[email]']`, `button[phx-submit='send_magic_link']`
- Password form: `#login_form_password`, `#login_form_password_email`, `#user_password`
- GA property ID input (AccountLive.Manage): `input[data-test='ga-property-id']`
- Style guide form: `textarea[data-test='style-guide-form']`, `button[data-test='clear-style-guide']`
- Style guide error display: `div[data-test='style-guide-error']`
- Agent pairing: `form[phx-submit='pair']`, `input[data-test='pair-token']`

### curl (API + MCP)

**When to use**: Testing OAuth endpoints, MCP bearer auth, public metadata endpoints, and integration verification.

**Example: Fetch OAuth server metadata**
```
curl -sS http://localhost:4007/.well-known/oauth-authorization-server
curl -sS http://localhost:4007/.well-known/oauth-protected-resource
```

**Example: MCP bearer token check (will 401 without token)**
```
curl -sS -H "Authorization: Bearer invalid" http://localhost:4007/mcp/ -X POST \
  -H "Content-Type: application/json" -d '{}' -w "\nStatus: %{http_code}\n"
```

**Example: MCP analytics-admin endpoint (requires valid bearer)**
```
curl -sS -H "Authorization: Bearer <token>" http://localhost:4007/mcp/analytics-admin -X POST \
  -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_custom_dimensions"}}'
```

**Routes by pipeline**:
- Public metadata: `/.well-known/oauth-*` (no auth)
- OAuth token/register/revoke: `/oauth/*` (`:api` pipeline, public)
- Agent version check: `/api/agent/version` (public)
- MCP main: `/mcp/` (bearer token via `RequireMcpToken` plug)
- MCP analytics-admin: `/mcp/analytics-admin` (bearer token via same plug)

### mix run (Seed scripts + dev tasks)

**When to use**: Populating QA data idempotently, testing story-specific scenarios, running linting workflows.

**Example: Primary seed script (3 users + accounts)**
```
mix run priv/repo/qa_seeds.exs
```
Output: `qa@marketmyspec.test`, `qa-agency@marketmyspec.test`, `qa-client@marketmyspec.test` with magic-link tokens.

**Example: Story 684 file-tree seed**
```
mix run priv/repo/qa_seeds_684.exs
```
Creates: nested markdown files + one non-markdown file in qa user's workspace.

**Example: Story 696 member-invitation seed**
```
mix run priv/repo/qa_seeds_696.exs
```
Creates: invitations + invite tokens for multi-user member management flows.

**Example: Story 738 polish_touchpoint scenarios (NOT a typical seed)**
```
VALE_STYLES_PATH=/path/to/styles MIX_ENV=dev mix run priv/repo/qa_738_scenarios.exs
```
Runs: 7 linting + polish scenarios in dev env. Exercises the `PolishTouchpoint` tool with clean/dirty/invalid prose variants. Output: test results (pass/fail per scenario). Rows persist in dev DB for inspection.

## Seed Strategy

### Primary seed: qa_seeds.exs

**Invocation**: `mix run priv/repo/qa_seeds.exs`

**What it creates**:
- **qa@marketmyspec.test** — individual account user (Journeys 1–3). Single account auto-created.
- **qa-agency@marketmyspec.test** — agency-account owner (Journeys 4 + 5 agency side). Agency account with type `:agency`.
- **qa-client@marketmyspec.test** — client-account owner (Journey 5 client side). Individual account with type `:individual`.

**Credentials printed**:
- Email, user ID, account name + ID + slug, magic-link token (20 min expiry) per user.

**Idempotency**: Checks for existing users by email; reuses if found. Confirms all users. Mints fresh tokens on every run.

### Story 684: qa_seeds_684.exs

**Invocation**: `mix run priv/repo/qa_seeds_684.exs`

**Prerequisite**: `qa_seeds.exs` must have been run (auto-runs transitively if needed).

**What it creates**:
- Markdown files (nested structure) in qa@marketmyspec.test's workspace.
- One non-markdown artifact (tests the "out-of-scope" path in FilesLive).
- Cross-account record (different user/account) to verify scoping.

**Idempotency**: Deletes + recreates files each run.

### Story 696: qa_seeds_696.exs

**Invocation**: `mix run priv/repo/qa_seeds_696.exs`

**Prerequisite**: `qa_seeds.exs` must have been run.

**What it creates**:
- Member invitations (story 696 workflow).
- Invite tokens for acceptance workflow testing.

**Credentials printed**: Email, token, acceptance URL per invite.

### Story 738: qa_738_scenarios.exs

**Invocation**: `VALE_STYLES_PATH=/path/to/styles MIX_ENV=dev mix run priv/repo/qa_738_scenarios.exs`

**What it does** (NOT a typical seed):
- Stages 7 touchpoints on a test thread.
- Calls `PolishTouchpoint` with clean/dirty/lint-fail/valid-json prose variants.
- Validates Vale config parsing and lint output JSON.
- Returns test results (pass/fail) to stdout; DB rows persist for inspection.

**Setup requirement**: Vale 3.14.2 must be in `PATH` (built into Docker runtime image). Local dev requires `VALE_STYLES_PATH` env var pointing to vendored styles in `priv/vale/styles/write-good/*.yml`.

## System Issues

### 1. MCP analytics-admin 401 on missing bearer (recently resolved)

**Issue**: The `/mcp/analytics-admin` endpoint crashed with `:persistent_term` error when accessed without a bearer token (before Story 736 completion).

**Resolution**: The supervised child for the analytics-admin server was added in commit `4ed3d2c`. The endpoint now 401s cleanly with `Plugs.RequireMcpToken` validation. No further action needed.

### 2. Vale styles path for local dev

**Issue**: Vale CLI requires `VALE_STYLES_PATH` env var to locate the vendored style pack (`priv/vale/styles/write-good/*.yml`).

**Resolution**: Set via `envs/dev.env` or inline before running `qa_738_scenarios.exs`. The Docker runtime image (UAT+prod) has Vale 3.14.2 + styles pre-baked.

### 3. OAuth issuer mismatch (dev.marketmyspec.com)

**Issue**: OAuth metadata endpoints return `issuer: "https://dev.marketmyspec.com"`, which requires DNS resolution or a tunnel from localhost.

**Status**: Not a blocker for browser-based auth (magic-link tokens work locally). Matters only for OAuth bearer token generation scripts that call `/.well-known/oauth-authorization-server` programmatically.

### 4. Google Analytics property ID requirement for MCP

**Issue**: The `polish_touchpoint` MCP tool (story 738) and the analytics-admin MCP server (story 736) require `Account.google_analytics_property_id` to be populated.

**Workaround**: The `AccountLive.Manage` form (at `/accounts/:id/manage`) now has a "Google Analytics 4 Property ID" input field (`data-test='ga-property-id'`). Paste a numeric property ID to enable analytics tools. Empty string clears the field.

### 5. Deployment: Hetzner + Kamal, not Fly.io

**Issue**: MarketMySpec deploys to Hetzner + Docker Compose (NOT Fly.io). Bootstrap creds via SSM at `/market_my_spec/{uat,prod}/*`.

**System**: UAT host 46.225.105.88 (nbg1), prod host 178.156.143.212 (ash). Per-env files at `/opt/market_my_spec/{uat,prod}.env` injected via `--env-file`. Kamal + Docker Compose on the host.

**Known trap**: `scripts/deploy` can silently push empty AWS keys if `render-env` fails in the `set -a; source <(...)` pipeline (fixed in `scripts/deploy` + `scripts/deploy-uat`, commits `4ed3d2c` / `cc38bad`). If container fails SSM auth, check `/opt/market_my_spec/*.env` for empty values and re-run deploy.

## Notes

### CodeMySpec OAuth integration

A third OAuth provider (`Integrations.Providers.Codemyspec`) is now available alongside Google + GitHub. It is configured via `CODEMYSPEC_CLIENT_ID`, `CODEMYSPEC_CLIENT_SECRET`, `CODEMYSPEC_URL` env vars and powers the floating feedback widget (`lib/market_my_spec_web/live/feedback_widget.ex`). The widget is mounted in `Layouts.app` and renders nothing if the user has not signed in to CodeMySpec via `/integrations`.

Issues filed through the widget POST to `<CODEMYSPEC_URL>/api/issues` via `MarketMySpec.Codemyspec.Client`.

### Vale linting in story 738

The `polish_touchpoint` MCP tool (and underlying `Linter.Vale` module) shells out to Vale CLI:
- `vale ls-config` — validates config syntax
- `vale --output JSON` — returns lint results as JSON

Lint loop is the only path for writing `touchpoints.polished_body`; direct DB updates bypass validation.

### New LiveView routes (stories 708, 710, 716, 731–733, 736)

- `/accounts/:id/venues` — `VenueLive.Index` (story 708 engagement search)
- `/accounts/:id/searches` — `SearchLive.Index` (story 710 saved searches)
- `/accounts/:id/threads` — `ThreadLive.Index` (thread list)
- `/accounts/:account_id/threads/:thread_id` — `ThreadLive.Show` (thread detail + comment form)
- `/accounts/:account_id/touchpoints` — `TouchpointLive.Index` (touchpoint list)
- `/accounts/:account_id/touchpoints/:touchpoint_id` — `TouchpointLive.Show` (story 716 lifecycle, comment_url paste form)
- `/accounts/:account_id/style-guide` — `LinterLive.StyleGuide` (story 736 Vale config paste, clears)
- `/oauth/authorize` — `McpAuthorizationLive` (MCP OAuth approval screen)
- `/agents`, `/agents/pair` — `AgentLive.Index`/`AgentLive.Pair` (stories 731–732 agent install + pair)

All routes require `:require_authenticated_user` (+ account membership). Test with Vibium MCP after login.

### Port stability

Dev port is consistently **4007** (configured in dev.exs, not 4000 to avoid collision with code_my_spec dev server).
