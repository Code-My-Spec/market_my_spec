# Sign Up And Sign In With GitHub

As a developer signing up for Market My Spec, I want to sign up and sign in with my GitHub account (mirroring the CodeMySpec auth pattern), so I can use my existing dev identity and skip credential management.

## Meta
- id: 2822237f-d08d-4ccd-a896-9151b52819f0
- number: 673
- status: in_progress
- priority: 1
- component: MarketMySpecWeb.UserLive.Login
- personas: founder

## Rules

### "Sign in with GitHub" appears on /users/log-in and /users/register; clicking it initiates Assent's GitHub OAuth flow with scopes "user:email read:user", redirects to GitHub, and on successful callback either creates a new user (matched by GitHub user id) or attaches the GitHub integration to an existing user — landing them authenticated on the MCP setup destination.

#### happy: Developer signs up via GitHub in one click [fb07f76d]
Given a new visitor with no MMS account loads /users/log-in
When they click "Sign in with GitHub"
Then they are redirected to https://github.com/login/oauth/authorize with the configured client_id, scope "user:email read:user", and redirect_uri "/integrations/oauth/callback/github"
When they complete GitHub's consent screen and GitHub redirects back with a valid auth code
Then MarketMySpec.Integrations.handle_callback creates a new MarketMySpec.Users.User using the GitHub primary email
And inserts a MarketMySpec.Integrations.Integration row with provider="github", encrypted access_token, provider_user_id set to GitHub's numeric user id, plus username + name + avatar_url metadata
And the session cookie is set
And the visitor is redirected to the MCP setup destination

#### failure: User cancels GitHub authorization and recovers cleanly [326914a9]
Given a visitor on /users/log-in clicks "Sign in with GitHub"
When GitHub's consent screen renders and they click "Cancel" / deny access
Then GitHub redirects to /integrations/oauth/callback/github with error=access_denied
And MarketMySpecWeb.IntegrationsController.callback flashes "You denied access. Please try again if you want to connect."
And the visitor lands back on /users/log-in (or /integrations) with no session cookie set
And no MarketMySpec.Users.User record was created
And no MarketMySpec.Integrations.Integration row was inserted

### The GitHub integration row persists provider_user_id (GitHub numeric id) as the stable identity, plus encrypted access_token via Cloak, plus username + name + avatar_url metadata; subsequent sign-ins match on provider_user_id, not email, since GitHub primary email may be private/missing.

#### happy: User with private GitHub email still resolves consistently [bf7316c5]
Given a returning user with a MarketMySpec.Integrations.Integration row for provider="github", provider_user_id="42424242", and a username "octofounder"
When they sign in again — and GitHub's response includes provider_user_id="42424242" but a null/missing primary email (privacy-protected)
Then MarketMySpec.Integrations.handle_callback matches the existing integration on (provider, provider_user_id)
And the existing user is reused; no duplicate user is created
And the integration row is upserted with the refreshed access_token and any updated username/name/avatar_url

#### failure: Callback missing GitHub user id is rejected [0d85479e]
Given GitHub's callback returns user data with no "id" or "sub" claim (e.g., a malformed response)
When MarketMySpec.Integrations.Providers.GitHub.normalize_user is invoked
Then it returns {:error, :missing_provider_user_id}
And no MarketMySpec.Users.User is created keyed only on email
And no MarketMySpec.Integrations.Integration row is inserted
And the controller flashes a clear error and redirects to /users/log-in
