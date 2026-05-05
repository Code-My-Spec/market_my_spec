# QA Story 678 Brief — Multi-Tenant Accounts

## Tool

web (Vibium MCP browser tools for all LiveView pages)

## Auth

All account routes are behind `:require_authenticated_user`. Use the dev mailbox to get magic-link tokens.

1. Register a new test user at `http://localhost:4008/users/register`
2. Check `http://localhost:4008/dev/mailbox` for the confirmation link
3. Navigate to the confirmation link and click "Confirm and stay logged in"
4. For a second user, log out, register another email, repeat

For a returning session with `qa@marketmyspec.test`, run the seed script (if mix run permission is available):

```
mix run priv/repo/qa_seeds.exs
```

Then navigate to the printed magic-link URL directly. If mix run is unavailable, use the log-in form at `http://localhost:4008/users/log-in` and check the mailbox for the login link.

App is running on port **4008** (not the default 4007 documented in plan.md).

## Seeds

The base seed script creates `qa@marketmyspec.test`. For this story, a second registered user is needed to test invitation and multi-account flows. Use the registration + mailbox flow described in Auth.

No custom seed script is required — the registration flow creates users fresh via the browser.

Note: invitation emails contain `http://localhost:4000` links (hardcoded base_url in config). Manually replace `4000` with `4008` when following invitation links.

## What To Test

### Scenario 1: New user default account (criterion 5766)
- Register a brand-new email, confirm via mailbox
- After confirmation, navigate to `/accounts`
- Expected: one individual account already created as default
- Actual behavior to verify or catch: does "You don't have any accounts yet" appear instead?

### Scenario 2: No-account redirect (criterion 5767 / 5779)
- Sign in as a brand-new user with no accounts
- Visit `/users/settings` (or any protected route)
- Expected: redirect to `/accounts/new`
- Also check: after confirm, is the user sent to `/accounts/new` instead of `/`?

### Scenario 3: Account creation and slug generation (criterion 5773)
- Sign in, go to `/accounts/new`
- Fill in "My Marketing Workspace", click Save Account
- Expected: redirected to `/accounts`, slug `my-marketing-workspace` visible in the account card

### Scenario 4: Duplicate slug rejection (criterion 5774)
- Create a second account with the same name as an existing one
- Expected: form stays open with "has already been taken" error on the slug field

### Scenario 5: Account creator is owner (criterion 5768)
- After creating an account, go to `/accounts/:id/members`
- Expected: creator listed with role "Owner"
- Also check: does the accounts LIST at `/accounts` show role next to each account card?

### Scenario 6: Self-service form has no type selector (criterion 5777)
- Go to `/accounts/new`
- Check the form HTML: no `account[type]` field should exist
- Submit with type=agency sneaked in (form inspect)
- Expected: account created as individual type

### Scenario 7: Individual account — no agency features (criterion 5775)
- On `/accounts`, check account cards for agency-only affordances
- Expected: no "manage clients" or "agency dashboard" links

### Scenario 8: Account picker with multiple accounts (criterion 5780)
- Create two accounts, visit `/accounts/picker`
- Expected: both accounts listed, `data-test="account-picker"` container present

### Scenario 9: Inviting a new member (criterion 5769)
- Go to `/accounts/:id/invitations`, click "Invite Member"
- Fill email + role, submit
- Expected: invitation sent, member gets exactly one role

### Scenario 10: Duplicate member rejection (criterion 5770)
- Accept an invitation so user becomes a member
- Try inviting that same user again via the invitations form
- Expected: clear rejection error shown (not silent creation of second invitation)

## Result Path

`.code_my_spec/qa/678/result.md`

## Setup Notes

- The app is running on port 4008, not 4007 (as noted in the QA plan)
- Invitation emails hardcode `http://localhost:4000` — replace port with 4008 manually
- The Account schema has no `type` field (no individual/agency distinction in the database)
- AccountLive module files (index.ex, form.ex, picker.ex, manage.ex, members.ex, invitations.ex) are NOT located in `lib/market_my_spec_web/live/account_live/` as separate files — they appear to be compiled and running (routes work) but source files are not present as top-level .ex files
