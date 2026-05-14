# Reddit API — Knowledge Reference

As of 2026-05-14.

## OAuth 2.0 App Types and Which Fits This Use Case

Reddit offers three app types (per https://github.com/reddit-archive/reddit/wiki/oauth2):

| Type | Runs on | Can keep secret | Access |
|---|---|---|---|
| **script** | Hardware you control (server/laptop) | Yes | Your account only |
| **web app** | Web service you control | Yes | Any user who authorizes |
| **installed app** | Devices you do not control (mobile) | No | Any user who authorizes |

**Use `script` for posting as johns10davenport.** A script app uses the OAuth2 password grant — no redirect, no user-facing consent screen. The app is locked to the account that registered it. Registration is at https://www.reddit.com/prefs/apps.

The password grant flow sends a POST to `https://www.reddit.com/api/v1/access_token` with HTTP Basic auth (client_id:client_secret) and form body:

```
grant_type=password
username=johns10davenport
password=<reddit password>
```

The response includes `access_token` (valid 1 hour) and no `refresh_token` (script apps can just re-authenticate with the password grant on expiry; there is no need to store a refresh token). If permanent access is desired via auth code flow, include `duration=permanent` in the authorization request to receive a refresh token.

All subsequent API calls use `Authorization: Bearer <access_token>` and target `https://oauth.reddit.com` (not `www.reddit.com`).

**Note [unverified]:** Reddit removed self-service API access in late 2023/2024 for new applications; personal/non-commercial script apps at low volume remain available but may require submitting a request. Confirm that the johns10davenport app is already registered or that a new registration is approved before building.

## Required Scopes

Request these three scopes, space-separated in the authorization URL:

| Scope | Needed for |
|---|---|
| `identity` | Confirm which account the token belongs to; required for any authenticated request |
| `read` | Search subreddits, read threads and comments |
| `submit` | Post a new comment (reply to an existing thread) |

Full scope list at https://www.reddit.com/api/v1/scopes. If editing existing comments is ever needed, add `edit`.

## Key API Endpoints

All requests go to `https://oauth.reddit.com` with `Authorization: Bearer <token>` and `User-Agent: market_my_spec/0.1 by johns10davenport` (Reddit requires a descriptive user agent).

### Search within a subreddit

```
GET /r/{subreddit}/search.json
```

Parameters:

| Param | Values | Notes |
|---|---|---|
| `q` | query string | Full-text search query |
| `restrict_sr` | `1` | Restrict to the target subreddit (omit for site-wide search) |
| `sort` | `relevance`, `new`, `hot`, `top`, `comments` | Use `new` for recency; `relevance` for quality |
| `t` | `hour`, `day`, `week`, `month`, `year`, `all` | Time window; combine with `sort=new` |
| `type` | `link`, `comment` | Omit for posts; `comment` for comment search |
| `limit` | 1–100 | Max results per page; default 25 |
| `after` | fullname string | Cursor for next page (e.g. `t3_abc123`) |
| `before` | fullname string | Cursor for previous page |

Per https://github.com/Pyprohly/reddit-api-doc-notes for full parameter reference.

### Read thread and comments

```
GET /r/{subreddit}/comments/{article_id}.json
```

or equivalently:

```
GET /comments/{article_id}.json
```

Returns a two-element array: `[post_listing, comment_listing]`. Add `?sort=new&limit=200` to get recent comments first. Add `?depth=3` to cap nesting depth.

### Post a comment

```
POST https://oauth.reddit.com/api/comment
Content-Type: application/x-www-form-urlencoded
Authorization: Bearer <token>
```

Body parameters:

| Param | Value |
|---|---|
| `api_type` | `json` |
| `thing_id` | fullname of the post or comment being replied to (e.g. `t3_abc123` for a post, `t1_xyz` for a comment) |
| `text` | Markdown content of the reply |

Fullname prefixes: `t1_` = comment, `t2_` = account, `t3_` = link/post, `t4_` = message, `t5_` = subreddit, `t6_` = award.

## Rate Limits

Reddit enforces a rolling window rate limit for OAuth-authenticated requests. Headers returned on every response:

| Header | Meaning |
|---|---|
| `X-Ratelimit-Used` | Approximate requests used in current period |
| `X-Ratelimit-Remaining` | Approximate requests remaining |
| `X-Ratelimit-Reset` | Seconds until current window resets |

The free tier limit is **100 authenticated requests per minute** (some sources still cite 60/min from older docs; 100/min is the current figure per https://painonsocial.com/blog/reddit-api-rate-limits-guide). When the limit is exceeded, Reddit returns HTTP 429 with a JSON body containing `retry_after` in seconds.

**Back-off strategy:** Read `X-Ratelimit-Remaining` before each call. If it drops to 0, sleep until `X-Ratelimit-Reset` seconds elapse. On 429, use `retry_after` from the response body. Req's built-in `:retry` step with a custom delay function can honor these headers directly.

**Note:** Undocumented per-action limits exist for commenting/voting at high frequency regardless of the rolling window limit. Space comment submissions by at least 2–5 seconds.

## Pagination

Listings use cursor-based pagination via `after` and `before` query parameters. Each listing response includes:

```json
{
  "data": {
    "after": "t3_abc123",
    "before": null,
    "children": [...],
    "dist": 25
  }
}
```

Pass `after=t3_abc123` to get the next page. Max `limit` per page is 100. `dist` is the count of items returned.

## Timestamps and Recency

Reddit does not expose "last activity" or "last comment time" on a post directly in listing or search results. The listing only provides:

- `created_utc` — Unix epoch (seconds, UTC) when the **post** was created
- `num_comments` — comment count (not a proxy for recency)

To determine the timestamp of the most recent comment on a thread, you must fetch the thread itself (`/comments/{id}.json?sort=new&limit=1`) and read `created_utc` from the first comment returned. This costs one extra API call per thread. For the engagement-finder use case, sorting by `sort=new` in subreddit search will surface recently-created posts; most recent-comment recency requires the extra call.

## Gotchas

**Shadowbans and spam filtering.** Reddit may silently drop comments from accounts it considers spammy without returning an error. Signs: the API returns 200 but the comment never appears when browsed logged out. Mitigation: maintain 100+ karma on johns10davenport (current account age is 6 years, which is favorable), space out posts, and avoid repetitive link patterns. Confirm the comment appeared after each submission by fetching the comment fullname returned in the `api/comment` response and verifying it.

**Subreddit-specific rules.** Many subreddits ban promotional links or restrict new-account posts. The `sr_detail` parameter on search includes subreddit metadata. Check `submission_type` and `allow_link_posts` in subreddit info before attempting to submit. Per project knowledge, r/SaaS auto-removes any comment with a codemyspec.com link (cooldown through 2026-06-22).

**Account-age karma requirements.** Individual subreddits can enforce minimum account age and karma thresholds through AutoModerator. These are not exposed in the API; the only signal is a 403 or removal notice after submission.

**User-Agent.** Reddit will block requests that use library defaults like `python-requests/2.x`. Always set `User-Agent: market_my_spec/0.1 by johns10davenport`.

**API access approval.** As of late 2024, Reddit requires approval for new API apps. Verify that the existing johns10davenport developer app is approved and its `client_id` / `client_secret` are in SSM before starting implementation.

## Sources

- Reddit OAuth2 wiki: https://github.com/reddit-archive/reddit/wiki/oauth2
- Reddit JSON structure: https://github.com/reddit-archive/reddit/wiki/JSON
- Rate limits guide (2026): https://painonsocial.com/blog/reddit-api-rate-limits-guide
- PRAW authentication docs: https://praw.readthedocs.io/en/stable/getting_started/authentication.html
- Shadowban patterns (2025): https://reddifier.com/blog/reddit-shadowbans-2025-how-they-work-how-to-detect-them-and-what-to-do-next
- Community API reference notes: https://github.com/Pyprohly/reddit-api-doc-notes
