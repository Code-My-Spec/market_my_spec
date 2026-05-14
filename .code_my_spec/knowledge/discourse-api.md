# Discourse API — Knowledge Reference (ElixirForum)

As of 2026-05-14.

Forum URL: https://elixirforum.com

## Anonymous Read Access

ElixirForum is a public Discourse forum. All topics and posts in public categories are readable without authentication by appending `.json` to any URL. No API key is required to read.

```
GET https://elixirforum.com/latest.json
GET https://elixirforum.com/t/{topic_id}.json
GET https://elixirforum.com/c/{slug}/{id}.json
```

These return JSON directly. Anonymous read is the correct approach for scanning and ingesting threads.

## Auth Options for Posting

Discourse provides two authentication mechanisms relevant here:

### Admin API Key

Generated in the admin panel (`/admin/api/keys`). Headers:

```
Api-Key: <key>
Api-Username: johns10davenport
```

Admin API keys bypass most per-user rate limits and trust-level restrictions but require admin access to generate. They are permanent until revoked. **This option requires admin access on elixirforum.com**, which johns10davenport likely does not have.

### User API Key (OAuth-style, no plugin required)

Discourse has a built-in User API Key specification (https://meta.discourse.org/t/user-api-keys-specification/48536) that allows any sufficiently trusted user to generate an application-scoped key via a browser-based OAuth-style consent flow. The application redirects the user to:

```
GET https://elixirforum.com/user-api-key/new
  ?application_name=MarketMySpec
  &client_id=<random UUID>
  &scopes=write
  &public_key=<RSA public key PEM>
  &nonce=<random string>
  &auth_redirect=<callback URL>
```

The forum redirects back to `auth_redirect` with an encrypted payload containing the user API key, decryptable with the paired private key. The resulting key is sent as:

```
User-Api-Key: <key>
User-Api-Client-Id: <client_id used during registration>
```

**Trust level requirement [unverified]:** By default, Discourse requires trust level 1 (Basic user) to access the User API. Some forums raise this. The johns10davenport account on ElixirForum has been active for years and almost certainly meets TL1 or higher. Confirm by attempting to generate a user API key; if denied, the error will say "Sorry, you do not have the required trust level to access the user API."

**Recommended approach for v1:** Generate the user API key manually once via the OAuth flow (or directly from the user preferences page at https://elixirforum.com/u/johns10davenport/preferences/apps) and store it in SSM. The key is long-lived and does not need to be refreshed. This avoids implementing the full OAuth key exchange in the application.

**Scopes for User API Key:** Use `write` scope, which covers creating posts and replies.

## Key Endpoints

### Latest topics (all categories)

```
GET https://elixirforum.com/latest.json?page=0
```

Returns up to 30 topics per page. Increment `page` until the `topic_list.topics` array is empty (returns 404 on overrun per some versions) or `more_topics_url` is absent from the response.

### Category topics

```
GET https://elixirforum.com/c/{slug}/{category_id}.json?page=0
```

Example categories relevant to CodeMySpec: `elixir`, `phoenix`, `jobs`. Get category IDs from:

```
GET https://elixirforum.com/categories.json
```

### Full topic (thread)

```
GET https://elixirforum.com/t/{topic_id}.json
```

Returns topic metadata and up to 20 posts by default. Paginate posts with `?page=2`, `?page=3`, etc. The API returns HTTP 404 when the page number exceeds available pages.

### Create a reply

```
POST https://elixirforum.com/posts.json
Content-Type: application/json
User-Api-Key: <key>
User-Api-Client-Id: <client_id>

{
  "raw": "Your reply text in Markdown",
  "topic_id": 12345
}
```

To start a new topic instead of replying, also include `"title"` and `"category"` fields and omit `topic_id`.

Authentication via Admin API uses `Api-Key` and `Api-Username` headers instead.

## Rate Limits

Discourse rate limiting is configured per-instance. Public instances typically enforce:

- Nginx-level: ~12 requests per second per IP (applies before Discourse logic)
- Discourse-level per user: varies by site settings (`DISCOURSE_MAX_REQS_PER_IP_PER_10_SECONDS`)
- Admin API keys may bypass some per-user limits but are still subject to nginx and global caps

When rate-limited, Discourse returns HTTP 429. The response may or may not include a `Retry-After` header depending on the instance version. Implement exponential backoff starting at 1 second when a 429 is received.

[unverified]: The specific limits configured on elixirforum.com are not publicly documented. For a single-user posting tool submitting a small number of replies per day, hitting these limits is unlikely.

**Daily post caps:** Discourse imposes per-user daily topic and post creation limits for non-admin users. Defaults are typically 20 topics and unlimited replies per day, though forum admins can tighten these. At current engagement volume (a few comments per day), this is not a practical constraint.

## Pagination Semantics

Unlike Reddit, Discourse uses integer page numbers starting at 0:

```
?page=0  →  items 0-29
?page=1  →  items 30-59
```

The `more_topics_url` field in `/latest.json` responses provides the next page URL when one exists. For topic post pagination (`/t/{id}.json`), pages start at 1 and 404 on overrun.

## Timestamps and Recency

Topic list entries expose three timestamp fields:

| Field | Meaning |
|---|---|
| `created_at` | When the original post (OP) was created |
| `last_posted_at` | Timestamp of the most recent reply — this is "last activity" |
| `bumped_at` | When the topic was last bumped (by a reply OR by a moderator bump); can differ from `last_posted_at` if an admin manually bumped without posting |

**Use `last_posted_at` for "last activity" filtering.** It reflects the most recent actual post in the thread. `bumped_at` may reflect admin actions rather than organic conversation.

## Trust Levels at ElixirForum

From https://elixirforum.com/t/elixir-forum-is-community-driven-trust-levels-info/87:

| TL | Name | Notable restrictions |
|---|---|---|
| 0 | New | Cannot post images, attachments, or more than 2 links per post; cannot mention more than 2 users |
| 1 | Basic | No TL0 restrictions; can use all core posting features |
| 2 | Member | 1.5x daily like limit |
| 3 | Regular | Can edit/recategorize all posts; 2x daily like limit |
| 4 | Leader | Moderator-equivalent powers |

The johns10davenport account has been active on ElixirForum for years and should be TL2 or TL3. TL1 restrictions (no more than 2 links per post at TL0) would be lifted. **Confirm actual trust level before wiring up the posting path.**

The TL0 link restriction (max 2 hyperlinks per post) is the only one that matters for engagement replies at TL0. If the account is TL1+, this is not a concern.

## Gotchas

**No link-spam filter comparable to Reddit.** ElixirForum does not auto-remove links, but forum norms discourage promotional links. Keep replies genuinely helpful with the link as supporting reference.

**Reply to existing topics only.** The posting endpoint requires `topic_id` to reply. Creating new topics requires additional fields and is a separate, higher-stakes action.

**User API key is account-bound.** A key generated for johns10davenport cannot be used on behalf of another user. This is fine for v1 single-tenant operation.

**ElixirForum does not expose a public OAuth application consent endpoint [unverified].** The user API key OAuth flow uses Discourse's built-in mechanism. Verify that elixirforum.com has not disabled the User API key feature by visiting https://elixirforum.com/user-api-key/new while logged in.

## Sources

- Discourse User API keys spec: https://meta.discourse.org/t/user-api-keys-specification/48536
- Discourse REST API docs: https://docs.discourse.org/
- Discourse rate limits thread: https://meta.discourse.org/t/rate-limits-for-api-users/63328
- ElixirForum trust levels: https://elixirforum.com/t/elixir-forum-is-community-driven-trust-levels-info/87
- Discourse API comprehensive examples: https://meta.discourse.org/t/discourse-rest-api-comprehensive-examples/274354
- Latest topics pagination: https://meta.discourse.org/t/latest-topics-api-pagination/127034
