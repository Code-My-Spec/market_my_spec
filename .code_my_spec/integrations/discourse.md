# Discourse (ElixirForum)

Discourse Source adapter for the engagement-finder, scoped to ElixirForum. Used by `MarketMySpec.Engagements.Source.ElixirForum` to read latest topics by category/tag and fetch full topics. **Read-only for v1** — posting back via API is not supported (see Notes). See stories 705/706 and (forthcoming) `architecture/decisions/discourse-integration.md`.

## Auth Type

none (anonymous read)

## Required Credentials

None. ElixirForum's public JSON endpoints (`/latest.json`, `/c/{slug}/{id}.json`, `/t/{topic_id}.json`) work unauthenticated.

## Verify Script

.code_my_spec/qa/scripts/verify_discourse.sh

## Status

unverified

## Notes

ElixirForum runs vanilla Discourse but does **not** expose the "User API Keys" section in user account preferences for non-admins, so we can't generate a posting credential for `johns10davenport`. Posting via API would require the forum admin (Jose Valim et al.) to either enable user-generated keys or issue a per-user one — out of scope for v1.

**Posting workflow for v1:** the LLM still calls `stage_response` for ElixirForum threads; the staged Touchpoint lands in the UI like any other; `MarketMySpecWeb.ThreadLive.Show` shows a "Copy to clipboard" affordance (instead of a "Post" button) for ElixirForum-source threads. John pastes into the ElixirForum reply box manually. The Touchpoint can still be transitioned to "posted" by John pasting the live reply URL into a small form on the LiveView.

`Source.ElixirForum.post/3` returns `{:error, :posting_not_supported}` to make this explicit at the contract layer; the orchestrator branches on this to render the manual-copy UI.

The verify script confirms the public read endpoint is reachable. End-to-end read flows (search + get_thread) are exercised by spex tests with recorded fixtures via ReqCassette.

Revisit if/when ElixirForum admins enable User API Keys, at which point this doc gets the credentials section and `Source.ElixirForum.post/3` switches to a real implementation.
