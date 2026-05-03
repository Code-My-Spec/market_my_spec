# GitHub OAuth

OAuth provider for GitHub sign-in. Used by `MarketMySpec.Integrations.Providers.GitHub` via Assent. See story 673 (Sign Up And Sign In With GitHub) and `architecture/decisions/pow-assent-integrations.md`.

## Auth Type

oauth2

## Required Credentials

- `GITHUB_CLIENT_ID` — OAuth App Client ID from GitHub. Create at https://github.com/settings/developers → OAuth Apps → New OAuth App. Set Authorization callback URL to `http://localhost:4000/integrations/oauth/callback/github` for dev and the prod equivalent.
- `GITHUB_CLIENT_SECRET` — OAuth App Client Secret from the same OAuth App. Generate (or reveal) on the app page; treat as secret.

## Verify Script

.code_my_spec/qa/scripts/verify_github_oauth.sh

## Status

verified

## Notes

This OAuth App is configured for the auth-code-with-redirect flow (web sign-in) and does not have Device Flow enabled. Real end-to-end validation happens when the app boots and you complete GitHub sign-in via the UI. The `verify_github_oauth.sh` script confirms credentials are loaded and api.github.com is reachable; that is the most a CLI script can prove without enabling device flow on the OAuth App or implementing a localhost-bound listener.
