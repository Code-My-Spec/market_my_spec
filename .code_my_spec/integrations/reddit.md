# Reddit

Reddit Source adapter for the engagement-finder. Used by `MarketMySpec.Engagements.Source.Reddit` to search subreddits and fetch threads. **Read-only for v1** — posting back via API is not supported (see Notes). See stories 705/706 and (forthcoming) `architecture/decisions/reddit-integration.md`.

## Auth Type

none (anonymous read)

## Required Credentials

- `REDDIT_USER_AGENT` — Required identifier sent on every API request. Reddit aggressively rate-limits requests without a unique, descriptive UA. Use the format `MarketMySpec/0.1 by johns10davenport`.

## Verify Script

.code_my_spec/qa/scripts/verify_reddit.sh

## Status

unverified

## Notes

Reddit's public JSON endpoints (e.g., `https://www.reddit.com/r/{subreddit}/search.json`, `https://www.reddit.com/r/{subreddit}/comments/{id}.json`) work without authentication. Anonymous reads max at ~60 QPM per IP — fine for engagement scanning, will need an authenticated path later if rate limits bite.

**Posting workflow for v1 (matches the ElixirForum read-only treatment):** the LLM still calls `stage_response` for Reddit threads; the staged Touchpoint lands in the UI; `MarketMySpecWeb.ThreadLive.Show` shows a "Copy to clipboard" affordance for both Reddit- and ElixirForum-source threads. John pastes into the platform's reply box manually. The Touchpoint can be transitioned to "posted" by John pasting the live comment URL back into a small form on the LiveView.

`Source.Reddit.post/3` returns `{:error, :posting_not_supported}` to make this explicit at the contract layer; the orchestrator branches on this to render the manual-copy UI.

The verify script confirms the public read endpoint is reachable with a proper User-Agent. End-to-end read flows (search + get_thread) are exercised by spex tests with recorded fixtures via ReqCassette.

Revisit if/when we need authenticated reads (higher rate limits) or actual programmatic posting — at which point this doc gets a credentials section (script-app OAuth or web-app OAuth depending on multi-tenant scope) and `Source.Reddit.post/3` switches to a real implementation.
