# Reddit Integration — Auth, Rate Limiting, and UTM Strategy

## Status
Accepted

## Context
The engagement-finder feature searches Reddit for threads where a reply from johns10davenport would be valuable, ingests thread content, and posts comments on behalf of that account. This requires OAuth 2.0 access to the Reddit API to search, read, and submit comments.

The Reddit API offers three app types (script, web, installed). The use case is posting as a single known account (johns10davenport) from a server the project controls, with no need for end-user OAuth flows.

## Decision

### Auth Strategy
Use a **script app** with the OAuth 2.0 **password grant**. A script app is server-side (can keep a secret), locked to the registering account (johns10davenport), and authenticates without a redirect flow. Tokens are fetched by POSTing `grant_type=password` with Reddit credentials to `https://www.reddit.com/api/v1/access_token` using HTTP Basic auth (client_id:client_secret).

Access tokens expire after 1 hour. Token refresh is handled by a `GenServer` (`Engagements.Reddit.TokenStore`) that re-authenticates via password grant when the current token is within 5 minutes of expiry. No refresh token is needed for script apps.

Credentials stored in SSM at `/market_my_spec/{env}/reddit_client_id`, `/market_my_spec/{env}/reddit_client_secret`, and `/market_my_spec/{env}/reddit_password`. Loaded at boot via `Secrets.load!/1`.

### Per-Account Scoping
The integration is scoped to johns10davenport for v1. The source credential model (`Engagements.SourceCredential`) is keyed by `account_id` from day one, so a future multi-tenant expansion does not require a schema migration. In practice, only one account_id will have Reddit credentials initially.

Required OAuth scopes: `identity read submit`.

### Rate-Limit Handling
Inspect `X-Ratelimit-Remaining` and `X-Ratelimit-Reset` response headers before each call. If remaining drops to 0, sleep until the reset window (the header value is seconds remaining). On HTTP 429, use the `retry_after` value from the response body. Req's `:retry` step with a custom `retry_delay` function handles this transparently at the client level (see `req-and-cassette-stack.md`).

Space comment submissions by at least 3 seconds regardless of the rate-limit window to avoid undocumented per-action throttling.

### UTM Scheme
Links included in Reddit replies use the following UTM parameters:

```
utm_source=reddit
utm_medium=engagement
utm_campaign={subreddit}
utm_content={thread_id}
```

Example: `https://codemyspec.com?utm_source=reddit&utm_medium=engagement&utm_campaign=elixir&utm_content=abc123`

The `utm_content` parameter captures the thread ID for attribution to specific engagement opportunities.

**Note:** r/SaaS auto-removes any comment containing a codemyspec.com link (cooldown through 2026-06-22). The engagement-finder must suppress link insertion for r/SaaS submissions or skip that subreddit for linked comments. This is a per-subreddit rule, not a per-reply decision; store it as configuration on the subreddit record.

## Consequences
- Script app auth is the simplest flow: no redirect URI, no user consent screen, no refresh token rotation. Trade-off: if the Reddit account password changes, SSM credentials must be updated and the app restarted.
- The `account_id` key on `SourceCredential` ensures multi-tenancy is not retrofitted later.
- UTM attribution enables measurement of engagement-finder ROI in GA4 without additional instrumentation.
- The `TokenStore` GenServer is a single point of failure for Reddit calls; it should be supervised under the main application supervisor with `:permanent` restart.
- Before deploying, confirm the johns10davenport developer app is approved by Reddit (API access approval has been required since late 2024).
