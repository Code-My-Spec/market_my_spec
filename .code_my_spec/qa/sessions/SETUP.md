# Persistent browser session setup

Step-by-step recipe for capturing a Vibium `storage_state` JSON that
lets every subsequent automated journey run skip the human-mediated
sign-in step. Run this once per environment, and again whenever a
saved session expires (the per-run sanity check will tell you).

## Prerequisites

- Vibium MCP server is connected and responding (the operator's Claude
  Code session must have the `mcp__vibium__*` tools available).
- You can sign in to the target environment in a real browser — i.e.
  your Google account is on the OAuth client's allowed list, or you
  can read magic-link emails from the target's email provider.

## The recipe (operator drives — agent runs the calls)

The agent invokes the Vibium tools below in order. Each step lists
the tool, args, and what to verify before moving on.

### 1. Launch a fresh browser

```
mcp__vibium__browser_launch   # default Chromium, headed so you can interact
```

A real browser window opens on your screen. Leave it open.

### 2. Navigate to the env's sign-in page

For UAT:
```
mcp__vibium__browser_navigate  url: https://uat.marketmyspec.com/users/log-in
```

For dev:
```
mcp__vibium__browser_navigate  url: http://localhost:4007/users/log-in
```

### 3. Sign in interactively

This is the only step that needs a human. Use whichever provider
has the env's redirect URI registered (currently Google for UAT —
see `.code_my_spec/qa/plan.md` for which OAuth clients are wired
per env).

- **Google:** click "Sign in with Google", complete the Google OAuth
  popup in the same browser window. You'll be redirected back to
  the app's `/auth/google/callback`.
- **Magic link:** type your email, click submit, open the email in
  another tab, click the link, return to the original tab.

You're done when the browser is sitting on a signed-in page like
`/accounts` or `/`.

### 4. Sanity-check signed-in state

```
mcp__vibium__browser_navigate  url: <env>/accounts
mcp__vibium__browser_get_url    # should NOT be /users/log-in
```

If `get_url` shows you got redirected to `/users/log-in`, the
sign-in didn't take — repeat step 3 in the same browser window.

### 5. Capture the storage state

```
mcp__vibium__browser_storage_state  path: .code_my_spec/qa/sessions/<env>.json
```

Verify:
- File exists at the path
- File contains a JSON object with a non-empty `cookies` array
- One of the cookie names is `_market_my_spec_web_user_remember_me`
  or similar (Phoenix's session cookie)

Set the file mode to 600:
```bash
chmod 600 .code_my_spec/qa/sessions/<env>.json
```

### 6. Close the browser

```
mcp__vibium__browser_quit
```

## Per-run consumption (in the journey test script)

At the very start of every journey test:

```
mcp__vibium__browser_launch
mcp__vibium__browser_restore_storage  path: .code_my_spec/qa/sessions/<env>.json
mcp__vibium__browser_navigate         url: <env>/accounts
mcp__vibium__browser_get_url
# if URL ends in /users/log-in → session expired → abort with a clear
# message, telling the operator to re-run SETUP.md against <env>
```

## When sessions expire

Phoenix's `signed_session` is good for ~30 days by default. Symptoms:

- Per-run sanity check fires the "redirected to /users/log-in" abort
- Any browser-driven step suddenly redirects to login mid-flow

Fix: re-run this SETUP.md against the affected env. The journey
test script keeps the rest of its logic intact.

## Security

- Session cookies in the JSON files are equivalent to "logged-in as
  you". Treat them like SSH keys.
- The `.code_my_spec/qa/sessions/` directory is `chmod 700` and the
  JSON files should be `chmod 600`.
- `.gitignore` excludes `*.json` in this directory — never commit one.
- If you suspect a session file leaked, sign out of all sessions in
  the target env (Account settings or via API) which invalidates the
  cookies, then re-run setup.

## Future improvements

- Wrap step 1–5 in a shell script (`scripts/qa-session-setup <env>`)
  that does the Vibium calls in sequence, so the operator only
  needs to do the sign-in click in step 3.
- Auto-rotate sessions on a cron (e.g. weekly re-auth via Cypress
  or a similar tool with persistent storage).
- Detect session expiry in journey scripts and prompt for re-setup
  rather than aborting.
