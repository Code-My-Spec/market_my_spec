# Discourse Integration — Auth Strategy and UTM Scheme (ElixirForum)

## Status
Accepted

## Context
The engagement-finder feature includes ElixirForum (https://elixirforum.com) as a source. The forum runs Discourse. The feature needs to search/read topics anonymously and post replies as johns10davenport.

Discourse offers two auth mechanisms for posting: an admin API key (requires admin access on the forum, which johns10davenport does not have) and a User API Key (a built-in OAuth-style flow available to trusted users). ElixirForum does not use a custom Discourse plugin for OAuth; the standard User API Key mechanism is the only path available to non-admin accounts.

## Decision

### Read Access
All topic scanning and thread ingestion uses **anonymous HTTP** (no auth headers). Public topics on ElixirForum are readable without authentication by appending `.json` to any topic or category URL. This minimizes credential surface area for the read path.

### Auth Strategy for Posting
Use a **Discourse User API Key** generated once manually for the johns10davenport account. The key is long-lived (does not expire unless revoked) and is stored in SSM at `/market_my_spec/{env}/discourse_user_api_key` and `/market_my_spec/{env}/discourse_user_api_client_id`.

Posting sends the key via two non-standard headers:

```
User-Api-Key: <key>
User-Api-Client-Id: <client_id>
```

No token refresh is needed. The implementation does not need to implement the full User API Key OAuth exchange flow for v1; the key is generated manually via the Discourse consent page and stored in SSM before first deploy.

**Pre-requisite [action required]:** Verify that the johns10davenport account meets the trust level requirement for User API Key access on elixirforum.com (default is TL1, which the account almost certainly exceeds). Visit https://elixirforum.com/u/johns10davenport/preferences/apps to confirm. If the UI shows an application management screen, the account qualifies.

### Per-Account Scoping
Same as Reddit: the `SourceCredential` record is keyed by `account_id`. Only johns10davenport credentials exist in v1.

### Rate Limits
Discourse rate limits on elixirforum.com are not publicly documented. Implement exponential backoff on HTTP 429 starting at 2 seconds. At expected engagement volume (fewer than 10 replies per day), limits are not a practical constraint.

Trust level at TL1+ removes the TL0 restriction of max 2 hyperlinks per post. Confirm the account is TL1+ before relying on multi-link replies.

### UTM Scheme
Links included in ElixirForum replies use:

```
utm_source=elixirforum
utm_medium=engagement
utm_campaign={category_slug}
utm_content={topic_id}
```

Example: `https://codemyspec.com?utm_source=elixirforum&utm_medium=engagement&utm_campaign=phoenix&utm_content=12345`

## Consequences
- Manual key generation is a one-time setup step and avoids implementing the full Discourse OAuth key-exchange flow in the application for v1. If multi-user or multi-forum support is needed later, the exchange flow can be implemented using the specification at https://meta.discourse.org/t/user-api-keys-specification/48536.
- Anonymous read is simpler, cheaper, and does not consume any rate-limit budget on the write credentials.
- The `last_posted_at` field on topic list entries is used (not `bumped_at`) to rank threads by most recent activity.
- ElixirForum does not have the same link-removal auto-moderation as Reddit. UTM links are safe to include in replies, within forum norms for promotional content.
