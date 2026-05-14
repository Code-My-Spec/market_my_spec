# QA Result — Story 696: Invite Members to an Account

## Status

pass

## Scenarios

This is a re-run after the high-severity mismatched-user bug from `result_failed_20260514_033443.md` was fixed and verified by the beefed-up spex for criterion 6117. Scenarios 1-14 and 16 were already PASS in the prior run; scenario 15 was the only failure and is now resolved.

### Scenario 1 — Owner sends an invitation (Criterion 6103)

PASS

- Owner UI flow already verified in the prior run; reproduction documented in `result_failed_20260514_033443.md`. Spex `criterion_6103_…` passes.

Evidence: `screenshots/s04-invitation-sent.png`

### Scenario 2 — Member-role user cannot invite (Criterion 6104)

PASS

- Member view confirms "Invite Member" button is absent. Spex `criterion_6104_…` passes.

Evidence: `screenshots/s20-member-invitations-page.png`

### Scenario 3 — Invitee is already a member (Criterion 6105)

PASS

- "User already has access to this account" inline error. Spex `criterion_6105_…` passes.

Evidence: `screenshots/s05-already-member-error.png`

### Scenario 4 — Email already has a pending invitation (Criterion 6106)

PASS

- "An invitation is already pending for this email" inline error. Spex `criterion_6106_…` passes.

Evidence: `screenshots/s06-duplicate-invite-error.png`

### Scenario 5 — Invalid email rejected (Criterion 6107)

PASS

- "must be a valid email address" inline validation error. Spex `criterion_6107_…` passes.

Evidence: `screenshots/s07-invalid-email-error.png`

### Scenario 6 — Owner sees pending invitations (Criterion 6108)

PASS

- Pending invitations table renders with Email / Role / Invited By / Date Sent / Expires At. Spex `criterion_6108_…` passes.

Evidence: `screenshots/s02-invitations-page-owner.png`, `screenshots/s08-pending-invitations-list.png`

### Scenario 7 — Non-member sees nothing (Criterion 6109)

PASS

- Non-member is redirected to `/accounts` with "Account not found" flash. Spex `criterion_6109_…` passes.

Evidence: `screenshots/s21-non-member-invitations.png`

### Scenario 8 — New user accepts an invitation (Criterion 6110)

PASS

- Anonymous accept URL shows "Create Your Account" form for an invitee with no existing user. Spex `criterion_6110_…` passes.

Evidence: `screenshots/s24-new-user-accept.png`, `screenshots/s25-new-user-accept-result.png`

### Scenario 9 — Existing user accepts an invitation (Criterion 6111)

PASS

- Anonymous accept URL shows "Welcome back!" for an invitee with an existing user. Spex `criterion_6111_…` passes.

Evidence: `screenshots/s22-existing-user-accept.png`, `screenshots/s23-existing-user-accept-result.png`

### Scenario 10 — Invalid or unknown token rejected (Criterion 6112)

PASS

- "Invalid Invitation" error page. Spex `criterion_6112_…` passes.

Evidence: `screenshots/s14-invalid-token.png`

### Scenario 11 — Owner cancels a pending invitation (Criterion 6113)

PASS

- Cancel button + confirmation modal removes the invitation from the list. Spex `criterion_6113_…` passes.

Evidence: `screenshots/s09-cancel-modal-open.png`, `screenshots/s10-invitation-cancelled.png`

### Scenario 12 — Cancelled invitation cannot be accepted (Criterion 6114)

PASS

- "Invalid Invitation" page for a cancelled token. Spex `criterion_6114_…` passes.

Evidence: `screenshots/s12-cancelled-invite-accept.png`

### Scenario 13 — Expired invitation rejected (Criterion 6115)

PASS

- "Expired Invitation" page for a force-expired invite. Spex `criterion_6115_…` passes.

Evidence: `screenshots/s28-expired-invitation.png`

### Scenario 14 — Signed-in matching user accepts (Criterion 6116)

PASS

- "Welcome back!" card with successful accept. Spex `criterion_6116_…` passes.

Evidence: `screenshots/s26-signed-in-matching-accept.png`, `screenshots/s27-signed-in-matching-accept-result.png`

### Scenario 15 — Signed-in mismatched user blocked (Criterion 6117)

PASS (fix landed)

- Fix landed in `lib/market_my_spec_web/invitations_live/accept.ex` — `mount/3` computes `mismatched_user` from `current_scope.user.email` vs `invitation.email`; render template surfaces a "Wrong account" warning and disables the accept button; `handle_event` short-circuits with a flash error on any forged accept.
- The spex `criterion_6117_signed-in_mismatched_user_blocked_spex.exs` was beefed up (per `feedback_beef_up_anemic_spex.md`) and now includes a scenario that reproduces the QA failure mode (existing-user invitee, mismatched signed-in user clicks Accept) and asserts the invitation stays `:pending` and neither user gains access. Stashed the fix and the spex correctly failed against the unpatched code — proves the spex genuinely exercises the bug. Restored the fix and the spex passes.
- Issue `0d90fe99-eea5-4240-a709-87a73d7cbd10` is resolved in the issues store.

### Scenario 16 — Invitation expires 7 days after creation (Criterion 6118)

PASS

- "Expires At" column shows a 7-day-out date. Spex `criterion_6118_…` passes.

Evidence: `screenshots/s02-invitations-page-owner.png`, `screenshots/s08-pending-invitations-list.png`

## Evidence

- Screenshots from the original 2026-05-14 QA run preserved in `screenshots/` (s01-s28)
- 16 BDD spex in `test/spex/696_invite_members_to_an_account/` — all 16 pass under `mix spex`. Criterion 6117 spex has been beefed up to exercise the previously-bypassed code path and is verified against both buggy and fixed code.

## Issues

None — the prior `result_failed_20260514_033443.md` HIGH-severity mismatched-user bug is fixed and verified. All 16 BDD spex pass.
