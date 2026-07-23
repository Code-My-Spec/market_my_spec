# Sign Up And Sign In With Google

As a user signing up for Market My Spec, I want to sign up and sign in with my Google account (mirroring the CodeMySpec auth pattern), so I don't have to manage another credential and onboarding is one click.

## Meta
- id: 43e45607-68d7-43cc-9021-1dec8490f418
- number: 672
- status: in_progress
- priority: 1
- component: MarketMySpecWeb.UserLive.Login
- personas: founder

## Rules

### "Sign in with Google" appears on /users/log-in and /users/register; clicking it initiates Assent's Google OAuth flow, redirects to Google, and on successful callback either creates a new user (matched by Google sub) or attaches the Google integration to an existing user — landing them authenticated on the MCP setup destination.

#### happy: New visitor signs up via Google in one click [3836d0f5]
Given a new visitor with no MMS account loads /users/log-in
When they click "Sign in with Google"
Then they are redirected to https://accounts.google.com/o/oauth2/v2/auth with the configured client_id, scope "email profile", and redirect_uri "/integrations/oauth/callback/google"
When they complete Google's consent screen and Google redirects back with a valid auth code
Then MarketMySpec.Integrations.handle_callback creates a new MarketMySpec.Users.User with the Google email
And inserts a MarketMySpec.Integrations.Integration row with provider="google", encrypted access_token + refresh_token, and provider_user_id set to the Google sub
And the session cookie is set
And the visitor is redirected to the MCP setup destination

#### failure: User denies Google consent and recovers cleanly [f7d36232]
Given a visitor on /users/log-in clicks "Sign in with Google"
When Google's consent screen renders and they click "Cancel" / deny access
Then Google redirects to /integrations/oauth/callback/google with error=access_denied
And MarketMySpecWeb.IntegrationsController.callback flashes "You denied access. Please try again if you want to connect."
And the visitor lands back on /users/log-in (or /integrations) with no session cookie set
And no MarketMySpec.Users.User record was created
And no MarketMySpec.Integrations.Integration row was inserted

### The Google integration row persists provider_user_id (Google sub) as the stable identity, plus encrypted access/refresh tokens via Cloak; subsequent sign-ins match on sub, not email, so email changes don't fork the user account.

#### happy: User changes Google email and still resolves to the same MMS account [f2f567f6]
Given an existing MarketMySpec.Users.User with a MarketMySpec.Integrations.Integration row for provider="google" and provider_user_id="12345" tied to Google email "old@gmail.com"
When that Google user changes their primary Google email to "new@gmail.com" and signs in again
Then Google's callback returns sub="12345" with email="new@gmail.com"
And MarketMySpec.Integrations.handle_callback matches the integration on (provider, provider_user_id) — not email
And the existing user is reused; no duplicate user is created
And the integration row is upserted with the refreshed tokens and updated email metadata

#### failure: Callback missing sub claim is rejected [da87ff43]
Given Google's callback returns user data with no "sub" claim (e.g., a malformed response)
When MarketMySpec.Integrations.Providers.Google.normalize_user is invoked
Then it returns {:error, :missing_provider_user_id}
And no MarketMySpec.Users.User is created keyed only on email
And no MarketMySpec.Integrations.Integration row is inserted
And the controller flashes a clear error and redirects to /users/log-in
