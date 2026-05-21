# QA Brief — Story 736: Paste a Vale prose-lint configuration onto my account

## Tool
Vibium browser MCP tools (`mcp__vibium__browser_*`) for all LiveView interactions.

## Auth
Use the magic-link URL printed by `mix run priv/repo/qa_seeds.exs`.

- Primary user (Sam): `qa@marketmyspec.test` — use `qa_user` magic-link for initial sign-in
- Secondary user (Bea): `qa-agency@marketmyspec.test` — use `agency_token` magic-link for cross-account test

The seeds script creates both users with fresh single-use tokens. Navigate to the magic-link URL directly in the browser to authenticate without going through the email flow.

## Seeds
```
mix run priv/repo/qa_seeds.exs
```

This creates / refreshes `qa@marketmyspec.test` (individual account owner) and `qa-agency@marketmyspec.test` (agency account owner). Both get fresh magic-link tokens. The QA user's account id is required for the style-guide URL — it is printed in the seed output.

After seeding, use the account id from the Accounts index page (`/accounts`) to construct the style-guide URL: `/accounts/:account_id/style-guide`.

## What To Test

### Scenario 1 — Valid .vale.ini saves and persists (Criterion 6520)
1. Sign in as `qa@marketmyspec.test` via magic-link.
2. Navigate to `/accounts` to get the account id.
3. Navigate to `/accounts/:account_id/style-guide`.
4. Screenshot the empty state.
5. Paste the following valid .vale.ini into the textarea (`[name='style_guide[vale_ini]']`):
   ```
   StylesPath = /app/priv/vale/styles
   MinAlertLevel = warning

   [*.md]
   BasedOnStyles = Vale, write-good
   ```
6. Click Save.
7. Screenshot the success flash ("Style guide saved.").
8. Reload the page (navigate again to the same URL).
9. Assert the textarea shows the saved body (`StylesPath`, `MinAlertLevel = warning`).
10. Screenshot the persisted state.

### Scenario 2 — Malformed .vale.ini is rejected; prior config intact (Criterion 6521)
1. (Continuing from Scenario 1, or re-save first if needed.)
2. Clear the textarea and paste a malformed config — pure garbage that vale will reject:
   ```
   not a config
   ```
3. Click Save.
4. Assert error message appears in `[data-test='style-guide-error']` or as a flash error.
5. Screenshot the error state.
6. Reload the page.
7. Assert the prior valid config body is still shown (not the garbage).
8. Screenshot to confirm unchanged state.

### Scenario 3 — Second valid config replaces first (Criterion 6522)
1. (Continuing with Sam's saved config from Scenario 1/2.)
2. Replace the textarea content with a different valid .vale.ini:
   ```
   StylesPath = /app/priv/vale/styles
   MinAlertLevel = suggestion

   [*.md]
   BasedOnStyles = Vale, write-good, proselint
   ```
3. Click Save.
4. Reload the page.
5. Assert `MinAlertLevel = suggestion` and `BasedOnStyles = Vale, write-good, proselint` are shown.
6. Assert `MinAlertLevel = warning` is NOT shown.
7. Screenshot.

### Scenario 4 — Clear configuration returns to empty state (Criterion 6523)
1. (With Sam's config saved from Scenario 3.)
2. Click the "Clear configuration" button (`[data-test='clear-style-guide']`).
3. Screenshot the empty state after clearing.
4. Reload the page.
5. Assert: no saved body shown, the empty-state intro text is visible ("No configuration saved yet").
6. Assert: "Clear configuration" button is no longer visible (only shown when a config exists).
7. Screenshot.

### Scenario 5 — Cross-account access denied (Criterion 6524)
1. Open a second browser session (navigate to sign-out first or use a separate flow).
2. Sign in as `qa-agency@marketmyspec.test` via its magic-link URL.
3. Attempt to navigate to `/accounts/:sam_account_id/style-guide` (Sam's account id).
4. Assert: redirected away or denied (not Sam's config body shown).
5. Screenshot the denied/redirect state.
6. Sign back in as Sam and reload his style-guide page.
7. Assert: Sam's config body is still intact.
8. Screenshot.

## Result Path
`.code_my_spec/qa/736/result.md`

Screenshots: `.code_my_spec/qa/736/screenshots/` (Vibium writes to `~/Pictures/Vibium/`; copy from there after each capture).
