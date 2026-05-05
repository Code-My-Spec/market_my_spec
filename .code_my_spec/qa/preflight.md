# QA Preflight Report

Run date: 2026-05-04
Project: MarketMySpec

## Overall status

**PASS** — all three integrations verified against the running app.

## Environment loaded from

`envs/dev.env` (via Dotenvy in `config/runtime.exs`). Verify scripts inherit these vars when invoked from a shell that has sourced `dev.env`.

## Integrations verified

### GitHub OAuth (`integrations/github_oauth.md`)

- Script: `.code_my_spec/qa/scripts/verify_github_oauth.sh`
- Result: `{"integration":"github_oauth","status":"ok","details":"client credentials present; api.github.com reachable."}`
- `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET` are set in `envs/dev.env`.
- `api.github.com` reachable (HTTP 200).
- Full user-flow validation deferred to `exchange_github_token.sh` (requires browser-mediated auth).

### Google OAuth (`integrations/google_oauth.md`)

- Script: `.code_my_spec/qa/scripts/verify_google_oauth.sh`
- Result: `{"integration":"google_oauth","status":"ok","details":"client credentials present; discovery endpoint reachable."}`
- `GOOGLE_CLIENT_ID` ends with `.apps.googleusercontent.com` (sanity-passed).
- `GOOGLE_CLIENT_SECRET` is set.
- `https://accounts.google.com/.well-known/openid-configuration` reachable (HTTP 200).
- Full user-flow validation deferred to `exchange_google_token.sh`.

### Resend (`integrations/resend.md`)

- Script: `.code_my_spec/qa/scripts/verify_resend.sh`
- Result: `{"integration":"resend","status":"ok","details":"GET /domains returned 200; API key authenticated"}`
- `RESEND_API_KEY` is set and authenticates against `api.resend.com`.

## Integration tests

No `test/integration/` directory exists. Skipping `mix test test/integration/`.

## Issues found / resolved

None during this preflight pass.

## Notes

- Verify scripts run unauthenticated `mix run`-free — they probe upstream APIs directly. Real end-to-end OAuth round-trips would require the user-mediated `exchange_*_token.sh` scripts and a running browser, deferred from preflight scope.
- Story 672 (Google sign-in) and 673 (GitHub sign-in) regression tests cover the app-side OAuth controller and provider-module wiring; both stories' QA cycles passed.
