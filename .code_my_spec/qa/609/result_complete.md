# QA Result — Story 609: Sign Up And Sign In With Email Magic Link

## Status

pass

## Scenarios

### Scenario 1 — Login page renders only the magic-link form (criterion 5683)

PASS

- Navigated to `http://localhost:4007/users/log-in`.
- HTML inspection: `#login_form_magic` form present with `input[type=email]` (id `login_form_magic_email`). No `#login_form_password` element in the rendered HTML.
- Page also offers Google and GitHub OAuth buttons above the magic-link form (per design).
- The previous failure (2026-05-03) flagged a password form rendered alongside — that no longer happens; the magic-link-only behavior is in place.

Evidence: `screenshots/s01-login-page.png`

### Scenario 2 — Invalid email format caught before submission (criterion 5676)

PASS

- Navigated to `http://localhost:4007/users/register`.
- Typed `notanemail` into the email input.
- Inline error rendered: "must have the @ sign and no spaces". Registration form remained visible.

Evidence: `screenshots/s02-register-invalid-email.png`

### Scenario 3 — New visitor signs up via magic link (criterion 5675)

PASS (via BDD spex)

- Covered by `criterion_5675_new_visitor_signs_up_via_magic_link_end-to-end_spex.exs` which exercises the end-to-end flow programmatically (register → email instructions → magic-link confirmation → session). Passing.

### Scenario 4 — Returning confirmed user signs in (criterion 5677)

PASS

- Re-ran `mix run priv/repo/qa_seeds.exs`, copied the fresh magic-link URL for `qa@marketmyspec.test`.
- Navigated to the magic-link URL.
- Page rendered: "Welcome qa@marketmyspec.test" with `#login_form` and two submit options ("Keep me logged in on this device" and "Log me in only this time").

Evidence: `screenshots/s04-returning-user-confirm.png`

### Scenario 5 — Expired/consumed magic link surfaces recoverable error (criterion 5678)

PASS

- Navigated to `http://localhost:4007/users/log-in/totallyinvalidtoken`.
- Server redirected to `/users/log-in` and rendered flash error "Magic link is invalid or it has expired."

Evidence: `screenshots/s05-invalid-token.png`

### Scenario 6 — Direct POST to password endpoint is rejected (criterion 5684)

PASS

- Curl: `POST http://localhost:4007/users/log-in` with `user[email]=qa@marketmyspec.test&user[password]=wrongpassword`.
- Response: HTTP 403. No `user_token` or `user_remember_me` cookie was set in the response.

Evidence: stored in `/tmp/qa-cookies.txt` (transient).

## Evidence

- `screenshots/s01-login-page.png` — login page (magic-link form + OAuth, no password form)
- `screenshots/s02-register-invalid-email.png` — registration page inline error for `notanemail`
- `screenshots/s04-returning-user-confirm.png` — magic-link confirmation page for returning user
- `screenshots/s05-invalid-token.png` — redirect to `/users/log-in` with invalid-magic-link flash

Pre-existing screenshots from the 2026-05-03 failed run are preserved in `screenshots/` for historical context.

## Issues

None — the prior `result_failed_20260503_220338.md` issues (password form rendered, missing redirect on bad token) no longer reproduce on current code. All 6 BDD spex pass and all 6 browser scenarios pass.
