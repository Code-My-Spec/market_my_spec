# QA Brief: Story 609 — Sign Up And Sign In With Email Magic Link

## Tool

web (Vibium MCP browser tools for all LiveView interactions)

## Auth

This story tests unauthenticated flows (sign-up, sign-in). No pre-auth required.

For scenarios that need a seeded confirmed user with a valid magic-link token, run the seed script and use the printed URL:

```
mix run priv/repo/qa_seeds.exs
# Prints: Magic-link sign-in: http://localhost:4007/users/log-in/<token>
```

The seeded user `qa@marketmyspec.test` is force-confirmed, so visiting the magic-link URL shows the returning-user `#login_form` (not the first-time `#confirmation_form`).

## Seeds

Run before testing to set up the confirmed QA user and a fresh magic-link token:

```
mix run priv/repo/qa_seeds.exs
```

Note the printed magic-link URL — it is needed for returning-user and invalid-link scenarios. The token is single-use and expires in 20 minutes; re-run the script if it gets consumed.

## What To Test

### Scenario 1: Login page renders only the magic-link form (criterion 5683)

- Navigate to `http://localhost:4007/users/log-in`
- Assert that `#login_form_magic` is present
- Assert that `#login_form_magic input[type=email]` is present
- Assert that `#login_form_password` is NOT present (the magic-link-only UI should not show a password form)
- Screenshot: initial login page state

**Note:** The source code (`login.ex`) currently renders BOTH `#login_form_magic` AND `#login_form_password` with a divider between them. The BDD spec asserts `refute has_element?(context.view, "#login_form_password")`. This is a potential app bug — verify visually during testing.

### Scenario 2: Invalid email format caught before submission (criterion 5676)

- Navigate to `http://localhost:4007/users/register`
- Screenshot: initial registration page state
- Change (type without submitting) the email field to `notanemail` (no @ sign)
- Assert inline error "must have the @ sign and no spaces" appears
- Assert `#registration_form` is still visible
- Clear and type `bad email@example.com` (email with spaces)
- Assert inline error "must have the @ sign and no spaces" appears
- Screenshot: error state

### Scenario 3: New visitor signs up via magic link (criterion 5675)

- Navigate to `http://localhost:4007/users/register`
- Submit a new unique email address (e.g., `newvisitor+<timestamp>@example.com`)
- Assert redirect to `/users/log-in`
- Assert flash message matching: `An email was sent to .*, please access it to confirm your account`
- Assert "Log in" heading is visible
- Screenshot: post-registration redirect state

For the unconfirmed user magic-link sub-scenarios, use the dev mailbox at `http://localhost:4007/dev/mailbox` to retrieve the token, or use an iex console to generate one directly. The BDD spec tests these via programmatic fixtures — verify the confirmation page UI by navigating to a token URL directly if possible.

### Scenario 4: Returning confirmed user signs in (criterion 5677)

- Run `mix run priv/repo/qa_seeds.exs` and copy the magic-link URL
- Navigate to the magic-link URL
- Assert `#login_form` is visible (not `#confirmation_form`)
- Assert the user's email (`qa@marketmyspec.test`) appears on the page
- Assert a "Keep me logged in on this device" or similar log-in button is visible
- Screenshot: returning-user confirmation page

### Scenario 5: Expired/consumed magic link surfaces recoverable error (criterion 5678)

- Navigate to `http://localhost:4007/users/log-in/totallyinvalidtoken`
- Assert redirect to `/users/log-in`
- Assert flash error "Magic link is invalid or it has expired"
- Screenshot: error state on login page
- If the seeded token from Scenario 4 was consumed: navigate to that same URL again
- Assert same redirect + error behavior

### Scenario 6: Direct POST to password endpoint is rejected (criterion 5684)

- Using curl, POST to `http://localhost:4007/users/log-in` with `user[email]` and `user[password]` fields
- Assert no session token is set in the response
- Assert the response does NOT redirect to `/` (the signed-in destination)
- Acceptable responses: 200, 302 to non-`/` destination, 400, 403, 404, 422

```bash
curl -c /tmp/qa-cookies.txt -b /tmp/qa-cookies.txt -sS -o /tmp/qa-post-response.txt \
  -w "%{http_code}\n" -X POST http://localhost:4007/users/log-in \
  -d "user[email]=qa@marketmyspec.test&user[password]=wrongpassword"
```

Check `/tmp/qa-cookies.txt` for absence of `user_token` session cookie.

## Result Path

`.code_my_spec/qa/609/result.md`

## Setup Notes

The dev server must be running on port 4007. Start it with `PORT=4007 mix phx.server` if not already running (see QA plan System Issues for the dotenvy PORT issue).

The Vibium screenshot landing directory ignores path prefixes — screenshots land in `~/Pictures/Vibium/<basename>`. Copy to `.code_my_spec/qa/609/screenshots/` after capture.

The `login.ex` source renders both `#login_form_magic` and `#login_form_password`. The BDD spec criterion 5683 asserts only the magic-link form is shown. This discrepancy should be verified visually and reported as an app bug if confirmed.
