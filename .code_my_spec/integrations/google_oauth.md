# Google OAuth

OAuth provider for Google sign-in. Used by `MarketMySpec.Integrations.Providers.Google` via Assent. See story 672 (Sign Up And Sign In With Google) and `architecture/decisions/pow-assent-integrations.md`.

## Auth Type

oauth2

## Required Credentials

- `GOOGLE_CLIENT_ID` — OAuth 2.0 Client ID from Google Cloud Console. Create at https://console.cloud.google.com/apis/credentials → Create Credentials → OAuth client ID → Web application. Authorized redirect URIs must include `http://localhost:4000/integrations/oauth/callback/google` for dev and the prod equivalent.
- `GOOGLE_CLIENT_SECRET` — OAuth 2.0 Client Secret from the same credential. Treat as secret; never commit.

## Verify Script

.code_my_spec/qa/scripts/verify_google_oauth.sh

## Status

verified

## Notes

The credential type is "Web application" (the only type compatible with our redirect-URI sign-in flow). Web-app clients can't use device flow or client_credentials grants — Google requires going through the auth-code-with-redirect flow, which needs a running Phoenix app to capture the callback. Full end-to-end validation happens when the app boots and you complete Google sign-in via the UI. The `verify_google_oauth.sh` script confirms credentials are loaded and Google's discovery endpoint is reachable; that is the most a CLI script can prove for this client type.
