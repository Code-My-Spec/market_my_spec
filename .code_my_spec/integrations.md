# Integrations

Index of third-party integrations for Market My Spec. Each entry links to its full spec under `integrations/{name}.md` with auth type, required env vars, verify script, and current status.

| Integration | Auth | Status | Spec |
|-------------|------|--------|------|
| Resend | api_token | verified | [resend.md](integrations/resend.md) |
| Google OAuth | oauth2 | verified | [google_oauth.md](integrations/google_oauth.md) |
| GitHub OAuth | oauth2 | verified | [github_oauth.md](integrations/github_oauth.md) |

## Required Environment Variables

```
RESEND_API_KEY
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
GITHUB_CLIENT_ID
GITHUB_CLIENT_SECRET
```

## Verify Procedure

After credentials are set in the environment, run each `.code_my_spec/qa/scripts/verify_*.sh` and check that stdout JSON has `"status": "ok"`. For OAuth integrations, also run `exchange_*_token.sh` to complete a real device-flow auth and prove client_id+client_secret pair work end-to-end.
