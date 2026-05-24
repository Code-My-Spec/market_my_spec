# Persistent browser sessions (gitignored)

This directory holds per-env Playwright/Vibium `storage_state` JSON files
that capture the cookies + localStorage of an interactive sign-in
session. Loading them at the start of an automated journey run skips
the human-mediated auth step (magic-link, Google OAuth, GitHub OAuth)
that would otherwise block every Vibium test.

**This directory is gitignored.** The JSON files are effectively your
session credentials — anyone with them is signed-in as you. Treat them
like SSH keys: chmod 600, never commit.

## Layout

```
.code_my_spec/qa/sessions/
├── README.md          # this file (the only checked-in thing in the parent .gitignore exclusion)
├── dev.json           # session for http://localhost:4007
├── uat.json           # session for https://uat.marketmyspec.com
└── prod.json          # session for https://marketmyspec.com (use sparingly)
```

## One-time setup (or whenever a session expires)

See [`SETUP.md`](SETUP.md) in this directory for the full Vibium
recipe. Short version:

1. Launch a fresh Vibium browser
2. Navigate to `<host>/users/log-in`
3. Sign in via Google (or whichever provider has UAT redirects registered)
4. Confirm `/accounts` loads as signed-in
5. Capture `browser_storage_state` to `.code_my_spec/qa/sessions/<env>.json`
6. `chmod 600` the file

## Per-run usage

At the start of every journey-test script:

1. Launch a fresh Vibium browser
2. Restore from `.code_my_spec/qa/sessions/<env>.json`
3. Sanity-check by navigating to `/accounts` — if redirected to
   `/users/log-in`, the session expired; abort and re-run the
   one-time setup
4. Drive the journey

## Expiration

Phoenix's `signed_session` config defaults to ~30 days. When you see
the redirect-to-login sanity check fire, refresh the session file.
Don't fight it — interactive re-auth once a month is cheaper than
making the test harness handle every OAuth provider's quirks.
