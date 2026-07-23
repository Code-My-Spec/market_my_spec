# Sign Up And Sign In With Email Magic Link

As a user, I want to sign up and sign in with just my email address using a magic link, so I can get to the interview without remembering a password.

## Meta
- id: 42cb9140-70d3-411f-850d-44572c853e0d
- number: 609
- status: in_progress
- priority: 1
- component: MarketMySpecWeb.UserLive.Confirmation
- personas: founder

## Rules

### A user signs up or signs in by submitting only their email at /users/register or /users/log-in — no password ever required, no separate "register vs log-in" branching. The system delivers a single-use, time-limited magic link to that email; clicking it lands the user authenticated.

#### happy: New visitor signs up via magic link end-to-end [fbda1a51]
Given a new visitor with no account loads /users/register
When they enter "qa@marketmyspec.test" into the user[email] field and submit the magic-link form
Then the system creates a user record and a login-context UserToken
And an email containing the magic link "/users/log-in/<token>" is delivered (visible at /dev/mailbox in dev)
When they click the link in the email
Then they land authenticated and the session cookie is set
And they are redirected to the post-sign-in destination (MCP setup guide)

#### failure: Invalid email format is caught before submission [7b0c1cea]
Given a visitor on /users/register
When they enter "not-an-email" into the user[email] field and attempt to submit
Then the form surfaces an inline validation error
And no user record is created
And no email is sent

#### happy: New visitor signs up via magic link end-to-end [079431ab]
Given a new visitor with no account loads /users/register
When they enter "qa@marketmyspec.test" into the user[email] field and submit the magic-link form
Then the system creates a user record and a login-context UserToken
And an email containing the magic link "/users/log-in/<token>" is delivered (visible at /dev/mailbox in dev)
When they click the link in the email
Then they land authenticated and the session cookie is set
And they are redirected to the post-sign-in destination (MCP setup guide)

#### failure: Invalid email format is caught before submission [f59d8607]
Given a visitor on /users/register
When they enter "not-an-email" into the user[email] field and attempt to submit
Then the form surfaces an inline validation error
And no user record is created
And no email is sent

### Magic links are single-use and time-limited (20 minutes per phx.gen.auth defaults). Expired or already-consumed links surface a clear error at /users/log-in and offer a one-click "request a new link" affordance — the user is never stranded.

#### happy: Returning user signs in with a fresh magic link [a04858bd]
Given an existing confirmed user "qa@marketmyspec.test" with no active session
When they submit their email at /users/log-in
Then a fresh single-use login-context UserToken is generated
And the magic-link email is delivered
When they click the link within 20 minutes
Then they land authenticated and the consumed token is invalidated

#### failure: Expired or consumed magic link surfaces a recoverable error [1058d40c]
Given a magic link that has either expired (older than 20 minutes) or been already consumed
When the user clicks the link
Then they are redirected to /users/log-in
And a clear error flashes: "This sign-in link is no longer valid"
And the page shows the email form pre-populated with the user's email and a "Send me a new link" button
When they click the button
Then a fresh magic-link email is delivered

#### happy: Returning user signs in with a fresh magic link [21730334]
Given an existing confirmed user "qa@marketmyspec.test" with no active session
When they submit their email at /users/log-in
Then a fresh single-use login-context UserToken is generated
And the magic-link email is delivered
When they click the link within 20 minutes
Then they land authenticated and the consumed token is invalidated

#### failure: Expired or consumed magic link surfaces a recoverable error [90dea0ee]
Given a magic link that has either expired (older than 20 minutes) or been already consumed
When the user clicks the link
Then they are redirected to /users/log-in
And a clear error flashes: "This sign-in link is no longer valid"
And the page shows the email form pre-populated with the user's email and a "Send me a new link" button
When they click the button
Then a fresh magic-link email is delivered

### /users/log-in renders only the magic-link form (single email field + submit). The phx.gen.auth-scaffolded password form and the "submit_password" event are removed — MMS does not support email+password authentication. The User schema retains no hashed_password column needed for runtime auth (the scaffolded field can stay if benign, but no UI exposes it).

#### happy: Login page renders only the magic-link form [7931db8a]
Given a visitor loads /users/log-in
When the page renders
Then exactly one form is present, with phx-submit="submit_magic" and a single user[email] field
And no password field, no "submit_password" event, and no "Log in with password" copy is anywhere on the page
And the OAuth buttons (Google, GitHub) appear as alternative sign-in paths alongside the magic-link form

#### failure: Direct POST to password endpoint is rejected [38e02df8]
Given a client tries to bypass the UI by POSTing user[email] + user[password] directly to /users/log-in
When the request reaches the controller / LiveView
Then the password is ignored — no password verification path exists
And the user is not authenticated by virtue of submitting a password
And the only sign-in routes that succeed are magic-link confirmation, Google OAuth, and GitHub OAuth

#### happy: Login page renders only the magic-link form [4f727fe5]
Given a visitor loads /users/log-in
When the page renders
Then exactly one form is present, with phx-submit="submit_magic" and a single user[email] field
And no password field, no "submit_password" event, and no "Log in with password" copy is anywhere on the page
And the OAuth buttons (Google, GitHub) appear as alternative sign-in paths alongside the magic-link form

#### failure: Direct POST to password endpoint is rejected [cd72f0b8]
Given a client tries to bypass the UI by POSTing user[email] + user[password] directly to /users/log-in
When the request reaches the controller / LiveView
Then the password is ignored — no password verification path exists
And the user is not authenticated by virtue of submitting a password
And the only sign-in routes that succeed are magic-link confirmation, Google OAuth, and GitHub OAuth
