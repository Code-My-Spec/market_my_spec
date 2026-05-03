# Qa Plan

## App Overview

Market My Spec is a Phoenix 1.8 / LiveView 1.1 app on Bandit + Postgres + Tailwind/DaisyUI. It runs a single OTP release with one HTTP listener — Endpoint on port **4007** in dev (default Phoenix is 4000; we run 4007 to avoid colliding with the locally-running CodeMySpec server). Authentication is **session cookie–based** (`phx.gen.auth` scaffold) with magic-link sign-in plus Google + GitHub OAuth via Assent (server-issued bearer tokens for MCP clients are not yet wired — there's no MCP endpoint and no `/.well-known/oauth-authorization-server` yet). Pipelines are `:browser` (HTML, CSRF, session, scope assignment), `:api` (declared, unused), and a dev-only `Phoenix.LiveDashboard` + Swoosh mailbox preview at `/dev/dashboard` and `/dev/mailbox`. Authenticated routes use `:require_authenticated_user` for `/users/settings*` and `/integrations*`.

| Pipeline | Path patterns | Auth model | Tool |
| --- | --- | --- | --- |
| `:browser` (public) | `/`, `/users/log-in`, `/users/log-in/:token`, `/users/register` | none / `mount_current_scope` | Vibium MCP browser tools |
| `:browser` + `:require_authenticated_user` | `/users/settings`, `/users/settings/confirm-email/:token`, `/integrations`, `/integrations/oauth/:provider`, `/integrations/oauth/callback/:provider` | session cookie set by `UserSessionController.create` | Vibium after seed-token sign-in |
| `:api` | none mounted | n/a | n/a until an API scope ships |
| dev-only | `/dev/dashboard`, `/dev/mailbox` | none in dev | curl + Vibium |

Base URL in dev: `http://localhost:4007`. There is currently no MCP / SSE endpoint and no OAuth-authorization-server metadata document — those land with the MCPController, MCPAuth, and Skills components.

## Tools Registry

### Vibium (browser MCP)

When to use: any LiveView interaction — log-in, registration, settings, integrations index, the future MCP setup guide and consent screen.

Login form selectors (from `lib/market_my_spec_web/live/user_live/login.ex`) — Phoenix names, not ids:

- Magic-link form: `phx-submit="submit_magic"`, email field name `user[email]`
- Password form: `phx-submit="submit_password"`, email name `user[email]`, password name `user[password]`, remember-me name `user[remember_me]` value `true`

Example invocation (via the QA agent's MCP tools, not shell):

```
browser_navigate http://localhost:4007/users/log-in
browser_fill name="user[email]" value="qa@marketmyspec.test"
browser_click "Send magic link"
```

Or simpler — sign in directly with the seeded magic-link token (skips the email round-trip):

```
browser_navigate <magic-link URL printed by qa_seeds.exs>
```

Screenshot landing dir on this box: Vibium writes screenshots to `~/Pictures/Vibium/<basename>` regardless of the directory portion of the `filename` argument — verified during this probe. Pass just a basename and pull from `~/Pictures/Vibium/`.

### curl (controllers, JSON, dev endpoints)

When to use: probing routes for status codes, hitting `UserSessionController` (the only non-LiveView controller for authenticated user actions), inspecting the dev dashboard / mailbox redirects, future API JSON endpoints, future OAuth metadata.

Probe the running app:

```
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4007/
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4007/users/log-in
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4007/.well-known/oauth-authorization-server
```

Current observed responses: `/` → 200, `/users/log-in` → 200, `/.well-known/oauth-authorization-server` → 404, `/dev/dashboard` → 302, `/dev/mailbox` → 200.

Authenticated curl is not currently useful — every authenticated route is a LiveView, and the LiveView WebSocket flow doesn't survive plain curl. Drive authenticated flows via Vibium.

### Integration verify scripts (`.code_my_spec/qa/scripts/*.sh`)

When to use: verifying third-party credentials are loaded and providers are reachable. Source `envs/dev.env` first.

```
set -a; source envs/dev.env; set +a
bash .code_my_spec/qa/scripts/verify_resend.sh
bash .code_my_spec/qa/scripts/verify_google_oauth.sh
bash .code_my_spec/qa/scripts/verify_github_oauth.sh
```

Each prints structured JSON; status `ok` means credentials present and provider reachable. The `exchange_*_token.sh` scripts target device-flow OAuth which the configured Google/GitHub clients don't support (web-app type for Google; device flow not enabled on the GitHub OAuth App) — full e2e validation happens by signing in via the actual app.

### mix run / mix tasks

When to use: seeding data, running migrations, running specific scripts that need the BEAM (one boot, in-process — never `for x in …; do mix run -e '…' ; done`).

```
mix ecto.migrate                                  # apply pending migrations
mix run priv/repo/qa_seeds.exs                    # seed QA user + print magic-link URL
MIX_ENV=test mix ecto.reset                       # nuke + re-create the test DB if it gets wedged
PORT=4007 mix phx.server                          # start the dev server on 4007 explicitly
```

Note: PORT must be passed explicitly until the dotenvy loading is verified — the `envs/dev.env` PORT=4007 entry was not picked up during this probe (server tried to bind 4000 and conflicted with another beam). See System Issues.

### iex (interactive inspection)

When to use: poking at live state during a QA session — fetching a user, verifying a token, inspecting OAuth state store contents.

```
PORT=4007 iex -S mix phx.server                   # boot with a REPL attached
# then: MarketMySpec.Users.get_user_by_email("qa@marketmyspec.test")
```

## Seed Strategy

Single Postgres Repo (`MarketMySpec.Repo`, `Ecto.Adapters.Postgres`) — no SQLite, no second DB. One seed script covers all of it.

### `priv/repo/qa_seeds.exs`

Run with `mix run priv/repo/qa_seeds.exs`. Idempotent — safe to re-run.

Creates / updates:

- `qa@marketmyspec.test` user (registered via `MarketMySpec.Users.register_user/1`, force-confirmed via `Repo.update!` so QA flows don't need to click an email link)
- A fresh single-use `users_tokens` row with context `login` so the magic-link sign-in URL works without sending email

Outputs:

- The seeded email + user id
- A direct magic-link sign-in URL of the form `http://localhost:4007/users/log-in/<encoded_token>` — copy/paste into Vibium to skip email-click

Run before any QA session that needs an authenticated user. Re-run between sessions if the token has been consumed (single-use).

## System Issues

### dotenvy doesn't pick up envs/dev.env in `mix phx.server`

What went wrong: `envs/dev.env` has `PORT=4007` but `mix phx.server` (no env prefix) bound 4000 and crashed with `:eaddrinuse` against the locally-running CodeMySpec beam on the same port. Other env vars (Google/GitHub/Resend creds) loaded fine when the verify scripts pre-sourced the file in shell, but Phoenix didn't see PORT.

Workaround: pass `PORT=4007 mix phx.server` explicitly. Confirmed boots cleanly on 4007 that way.

Status: open. Likely a Dotenvy load-order issue (Dotenvy.source! runs in `config/runtime.exs`, but Phoenix's HTTP port is configured at compile time in `config/dev.exs` indirectly via the Endpoint). Investigate whether dev's Endpoint config needs a runtime port override or whether the dotenvy invocation needs `overload!: true` to win against System.get_env's empty default. Until fixed, every `mix phx.server` invocation in dev needs an explicit `PORT=4007` prefix and any other secret env vars need shell-side pre-sourcing.

### No OAuth authorization-server metadata yet

What went wrong: probing `/.well-known/oauth-authorization-server` returns 404. The MCPAuth context and the MCPController surface haven't been built yet, so MCP clients can't discover the OAuth endpoints.

Workaround: none — this is expected pre-implementation state. Note in QA briefs that any MCP-side flow is non-testable until those components ship.

Status: open. Resolves when the MCPAuth + MCPController components are implemented.

### Vibium screenshot landing dir ignores path

What went wrong: `browser_screenshot { filename: "x/y.png" }` writes to `~/Pictures/Vibium/y.png` regardless of the `x/` portion. Verified on this box.

Workaround: pass just a basename (`filename: "qa-login.png"`) and read from `~/Pictures/Vibium/`. If the QA brief needs a per-run subdir, copy from `~/Pictures/Vibium/` after the screenshot lands.

Status: open / external — Vibium-side issue, not ours.
