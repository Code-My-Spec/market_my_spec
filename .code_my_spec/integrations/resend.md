# Resend

Transactional email provider used via Swoosh in production. See `architecture/decisions/resend.md`.

## Auth Type

api_token

## Required Credentials

- `RESEND_API_KEY` — API key from the Resend dashboard. Get one at https://resend.com/api-keys. Use a dev/test key for local; create a separate prod key for deployment.

## Verify Script

.code_my_spec/qa/scripts/verify_resend.sh

## Status

verified
