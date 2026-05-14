# QA Result — Story 672: Sign Up And Sign In With Google

## Status

pass

## Scenarios

### Scenario 1 — Registration page surfaces Google sign-up (open criterion from story description)

PASS

- `curl -sS http://localhost:4007/users/register | grep -E "google-sign-in|/auth/google"` confirms `data-test="google-sign-in"` linking to `/auth/google` is now rendered on `/users/register`.
- The previously-flagged gap ("Currently the button is only on `/users/log-in`") is closed.

Evidence: `screenshots/672-register-google.png`

### Scenario 2 — Login page surfaces Google sign-in

PASS

- `curl -sS http://localhost:4007/users/log-in | grep -E "google-sign-in"` confirms `data-test="google-sign-in"` → `/auth/google` is rendered on `/users/log-in`.

### Scenario 3 — New visitor signs up via Google in one click (criterion 5679)

PASS (via BDD spex)

- `criterion_5679_new_visitor_signs_up_via_google_in_one_click_spex.exs` exercises the full PowAssent + cms_gen integration sign-up flow end-to-end against a stubbed Google OAuth response (using ExVCR fixtures). Passing.

### Scenario 4 — User denies Google consent and recovers cleanly (criterion 5680)

PASS (via BDD spex)

- `criterion_5680_user_denies_google_consent_and_recovers_cleanly_spex.exs` exercises the OAuth callback with the user-denied consent response and asserts a clean redirect back to `/users/log-in` with a flash message. Passing.

### Scenario 5 — User changes Google email and still resolves to same MMS account (criterion 5681)

PASS (via BDD spex)

- `criterion_5681_user_changes_google_email_and_still_resolves_to_the_same_mms_account_spex.exs` exercises the provider-identity lookup (Google `sub` claim) so that an email change at the IdP still resolves to the same MarketMySpec user via the persisted identity record. Passing.

### Scenario 6 — Callback missing `sub` claim is rejected (criterion 5682)

PASS (via BDD spex)

- `criterion_5682_callback_missing_sub_claim_is_rejected_spex.exs` exercises a malformed callback with the `sub` claim stripped and asserts the controller rejects the sign-in with an error flash. The spex output emits a `[error] OAuth sign-in callback failed for google: "Missing 'sub' in ID Token claims"` log line confirming the error path runs. Passing.

## Evidence

- `screenshots/672-register-google.png` — `/users/register` showing the Google sign-in button on the registration page (the previously-missing entry point)
- 4 BDD spex in `test/spex/672_sign_up_and_sign_in_with_google/` — all 4 pass under `mix spex`

## Issues

None — the prior `result_failed_20260503_223324.md` issues no longer reproduce. The `data-test="google-sign-in"` button is now on both `/users/log-in` and `/users/register`. All 4 BDD spex pass.
