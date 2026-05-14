# QA Result — Story 673: Sign Up And Sign In With GitHub

## Status

pass

## Scenarios

### Scenario 1 — Registration page surfaces GitHub sign-up (open criterion from story description)

PASS

- `curl -sS http://localhost:4007/users/register | grep -E "github-sign-in|/auth/github"` confirms `data-test="github-sign-in"` linking to `/auth/github` is rendered on `/users/register`.
- The previously-flagged gap ("Currently the button is only on `/users/log-in`") is closed.

Evidence: `screenshots/673-register-github.png`

### Scenario 2 — Login page surfaces GitHub sign-in

PASS

- `curl -sS http://localhost:4007/users/log-in | grep -E "github-sign-in"` confirms `data-test="github-sign-in"` → `/auth/github` is rendered on `/users/log-in`.

### Scenario 3 — Developer signs up via GitHub in one click (criterion 5685)

PASS (via BDD spex)

- `criterion_5685_developer_signs_up_via_github_in_one_click_spex.exs` exercises the full PowAssent + cms_gen integration sign-up flow end-to-end against a stubbed GitHub OAuth response. Passing.

### Scenario 4 — User cancels GitHub authorization and recovers cleanly (criterion 5686)

PASS (via BDD spex)

- `criterion_5686_user_cancels_github_authorization_and_recovers_cleanly_spex.exs` exercises the OAuth callback with the user-cancelled response and asserts a clean redirect back to `/users/log-in` with a flash message. Passing.

### Scenario 5 — User with private GitHub email still resolves consistently (criterion 5687)

PASS (via BDD spex)

- `criterion_5687_user_with_private_github_email_still_resolves_consistently_spex.exs` exercises the provider-identity lookup so that a user with a private email at GitHub still resolves to the same MarketMySpec user via the persisted identity record. Passing.

### Scenario 6 — Callback missing GitHub user id is rejected (criterion 5688)

PASS (via BDD spex)

- `criterion_5688_callback_missing_github_user_id_is_rejected_spex.exs` exercises a malformed callback with the GitHub user id stripped and asserts the controller rejects the sign-in. The spex output emits `[error] OAuth sign-in callback failed for github: :missing_provider_user_id` confirming the error path runs. Passing.

## Evidence

- `screenshots/673-register-github.png` — `/users/register` with the GitHub sign-up entry point visible (shared screenshot with story 672 since both buttons live on the same registration page)
- 4 BDD spex in `test/spex/673_sign_up_and_sign_in_with_github/` — all 4 pass under `mix spex`

## Issues

None — the prior `result_failed_20260503_224532.md` issues no longer reproduce. The `data-test="github-sign-in"` button is on both `/users/log-in` and `/users/register`. All 4 BDD spex pass.
