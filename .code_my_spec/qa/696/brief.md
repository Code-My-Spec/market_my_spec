# QA Brief — Story 696: Invite Members to an Account

## Tool

web (Vibium MCP browser tools for all LiveView pages; all invitation routes are in the `:browser` pipeline)

## Auth

Run the seed script to get fresh magic-link tokens:

```
mix run priv/repo/qa_seeds_696.exs
```

The script prints two magic-link URLs:
- Owner login: `http://localhost:4008/users/log-in/<owner_token>`
- Member login: `http://localhost:4008/users/log-in/<member_token>`

Navigate to the owner magic-link URL in the browser to sign in as the account owner. The link is single-use — re-run the seed script if the token has been consumed.

## Seeds

Run before testing:

```
mix run priv/repo/qa_seeds_696.exs
```

Creates:
- `qa-owner@marketmyspec.test` — account owner with an individual account ("QA Owner Account")
- `qa-member@marketmyspec.test` — member-role user in the owner's account
- `qa-invited@marketmyspec.test` — existing user with a pending invitation (for duplicate-invite test)
- Pending invitation to `pending-invite@example.com` (admin role, for list display test)

Key IDs from a sample run (re-run to get fresh tokens and actual IDs):
- Account ID: `c9bdd426-b646-4083-ba0d-e678cdc5fa55`
- Invitations page: `http://localhost:4008/accounts/c9bdd426-b646-4083-ba0d-e678cdc5fa55/invitations`

## What To Test

### Scenario 1 — Owner sends an invitation (Criterion 6103)
1. Sign in as `qa-owner@marketmyspec.test` using the magic-link from the seed script
2. Navigate to the invitations page: `/accounts/<account_id>/invitations`
3. Click "Invite Member" button (phx-click="toggle_invite_form")
4. Fill in email `new-invite@example.com` and role "member"
5. Submit the form
6. Expect: invitation appears in the pending invitations table with the email and role visible

### Scenario 2 — Member-role user cannot invite (Criterion 6104)
1. Sign in as `qa-member@marketmyspec.test` using the magic-link from the seed script
2. Navigate to the invitations page: `/accounts/<account_id>/invitations`
3. Expect: "Invite Member" button is NOT present, OR page redirects away (member has no manage permissions)

### Scenario 3 — Invitee is already a member (Criterion 6105)
1. Sign in as `qa-owner@marketmyspec.test`
2. Navigate to the invitations page
3. Click "Invite Member" and submit `qa-member@marketmyspec.test` (who is already a member)
4. Expect: error message containing "User already has access to this account" or similar

### Scenario 4 — Email already has a pending invitation (Criterion 6106)
1. Sign in as `qa-owner@marketmyspec.test`
2. Navigate to the invitations page
3. Click "Invite Member" and submit `qa-invited@marketmyspec.test` (already has a pending invite)
4. Expect: error message containing "An invitation is already pending for this email" or similar

### Scenario 5 — Invalid email rejected (Criterion 6107)
1. Sign in as `qa-owner@marketmyspec.test`
2. Navigate to the invitations page
3. Click "Invite Member" and submit `not-an-email` as the email
4. Expect: validation error about invalid email format

### Scenario 6 — Owner sees pending invitations (Criterion 6108)
1. Sign in as `qa-owner@marketmyspec.test`
2. Navigate to the invitations page
3. Expect: pending invitations table shows `pending-invite@example.com` (admin role) and `qa-invited@marketmyspec.test` (member role) with their details including Expires At column

### Scenario 7 — Non-member sees nothing (Criterion 6109)
1. Sign in as `qa@marketmyspec.test` (the standard QA user from `qa_seeds.exs`, not a member of the owner's account)
2. Attempt to navigate to the owner's invitations page
3. Expect: redirect away from the page (to `/accounts` or similar) — no invitation data shown

### Scenario 8 — New user accepts an invitation (Criterion 6110)
1. Navigate (without signing in) to `/invitations/accept/<invitation_token>` for `pending-invite@example.com`
   - Note: the token is not stored by seeds; use the database or create a fresh invitation to get the token
   - Alternative: use the accept endpoint with a known token from the DB via mix run
2. Expect: page shows "Create Your Account" section (since pending-invite@example.com has no account)
3. Click "Create Account & Accept Invitation"
4. Expect: redirect to `/users/log-in` with success flash

### Scenario 9 — Existing user accepts an invitation (Criterion 6111)
1. Navigate (without signing in) to `/invitations/accept/<invitation_token>` for `qa-invited@marketmyspec.test`
   - Get the token from the DB or by creating a fresh invitation
2. Expect: page shows "Welcome back!" section (since qa-invited@marketmyspec.test has an account)
3. Click "Accept Invitation"
4. Expect: redirect to `/users/log-in`

### Scenario 10 — Invalid or unknown token rejected (Criterion 6112)
1. Navigate to `/invitations/accept/totallybogustoken123`
2. Expect: page shows "Invalid Invitation" error message

### Scenario 11 — Owner cancels a pending invitation (Criterion 6113)
1. Sign in as `qa-owner@marketmyspec.test`
2. Navigate to the invitations page
3. Click "Cancel" button on a pending invitation
4. Confirm the cancellation in the modal by clicking the confirm button
5. Expect: invitation disappears from the pending list

### Scenario 12 — Cancelled invitation cannot be accepted (Criterion 6114)
1. After cancelling an invitation (Scenario 11), try to navigate to its accept URL
2. Expect: "Invalid Invitation" error (since status is :declined after cancellation)

### Scenario 13 — Expired invitation rejected (Criterion 6115)
1. Create an invitation and force-expire it via the database (or a mix run script)
2. Navigate to its accept URL
3. Expect: "Expired Invitation" error message

### Scenario 14 — Signed-in matching user accepts (Criterion 6116)
1. Sign in as `qa-invited@marketmyspec.test`
2. Navigate to `/invitations/accept/<token>` for their pending invitation
3. Expect: "Welcome back!" card is visible, with the account name shown
4. Click "Accept Invitation"
5. Expect: redirect to `/users/log-in`

### Scenario 15 — Signed-in mismatched user blocked (Criterion 6117)
1. Sign in as `qa-owner@marketmyspec.test`
2. Navigate to `/invitations/accept/<token>` for the `pending-invite@example.com` invitation
3. Expect: page shows the invitation addressed to `pending-invite@example.com` AND shows "Create Your Account" (since pending-invite@example.com has no user account), not the "Welcome back" path for the signed-in user

### Scenario 16 — Invitation expires 7 days after creation (Criterion 6118)
1. Sign in as `qa-owner@marketmyspec.test`
2. Navigate to the invitations page
3. Expect: "Expires At" column is visible in the pending invitations table, showing a date approximately 7 days from the current date

## Setup Notes

The invitations table stores tokens as a hash. To get the raw token for accept URL testing, either:
- Use a fresh invitation created by clicking the invite form in the browser (the email is sent to Swoosh mailbox at `/dev/mailbox`; the link in the email contains the token)
- Or create an invitation via `mix run -e` with inline Elixir using `Accounts.invite_user/4` and capture the returned invitation token field

For Scenarios 8, 9, 13, 14, 15 that need invitation tokens, navigate to `/dev/mailbox` after submitting the invite form to retrieve the tokenized link from the email preview.

## Result Path

`.code_my_spec/qa/696/result.md`
