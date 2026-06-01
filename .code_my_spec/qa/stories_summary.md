# Stories

## Story 609 — Sign Up And Sign In With Email Magic Link

As a user, I want to sign up and sign in with just my email address using a magic link, so I can get to the interview without remembering a password.

- TBD
- New visitor signs up via magic link end-to-end
- Invalid email format is caught before submission
- Returning user signs in with a fresh magic link
- Expired or consumed magic link surfaces a recoverable error
- Login page renders only the magic-link form
- Direct POST to password endpoint is rejected
- New visitor signs up via magic link end-to-end
- Invalid email format is caught before submission
- Returning user signs in with a fresh magic link
- Expired or consumed magic link surfaces a recoverable error
- Login page renders only the magic-link form
- Direct POST to password endpoint is rejected

## Story 611 — View MCP Connection Instructions

As an authenticated user, I want clear instructions for connecting Market My Spec as an MCP server in Claude Code (server URL, OAuth flow), so I can complete setup without guessing.

- TBD
- Signed-in user lands on /mcp-setup with everything they need
- Page missing server URL or install command is rejected
- Anonymous visitor is bounced through sign-in to /mcp-setup
- Anonymous request gets no connection details in the response body

## Story 612 — OAuth Authentication For MCP Connection

As a user installing the Market My Spec MCP, I want to authenticate via OAuth (the same flow CodeMySpec uses), so the server can identify me without me copying tokens, and revocation/rotation are handled by the OAuth provider rather than a custom token-management UI.

- TBD
- Claude Code completes OAuth and receives a bearer token
- Token request with bad PKCE verifier is rejected
- MCP client auto-discovers endpoints via well-known metadata
- Metadata document missing endpoints fails discovery
- MCP request with valid bearer is authenticated
- Expired bearer token returns 401 with re-auth pointer
- Claude Code self-registers as an OAuth client
- Registration request without redirect_uris is rejected
- User revokes a token and the MCP endpoint rejects it
- Revoke request with invalid token format is rejected
- MCP client discovers auth server from MCP endpoint URL
- Document missing authorization_servers fails RFC 9728 validation

## Story 633 — Public Landing Page

As a visitor to the Market My Spec landing page, I want a clear page that explains what Market My Spec does, who it is for (AI-native solo founders), and that it requires bringing my own Claude account, so I can decide whether to sign up without confusion about cost or fit.

- TBD
- Visitor sees a real strategy artifact in the hero
- Hero with no artifact fails the proof-on-page bar
- Visitor copies install command without an auth gate
- Sign-up gate in front of install command is rejected
- BYO-Claude lives below hero as a benefit line
- Hero with BYO-Claude warning copy is rejected
- Page passes the messaging-guide phrase audit
- Draft with banned phrase or enterprise framing is rejected
- Agency visitor finds the Talk-to-John lane below install
- Equal-weight agency CTA next to install is rejected

## Story 634 — MCP Setup Guide

As a new user, I want a step-by-step setup guide for installing the Market My Spec MCP in Claude Code (install command, OAuth sign-in, first interview), so I can go from sign-up to interview start without trial and error.

- TBD
- New user follows guide top-to-bottom and ships first interview
- Page lacking expected-result verification step is rejected
- User hits port conflict and recovers via troubleshooting block
- Page missing one of the three required troubleshooting blocks is rejected

## Story 672 — Sign Up And Sign In With Google

As a user signing up for Market My Spec, I want to sign up and sign in with my Google account (mirroring the CodeMySpec auth pattern), so I don't have to manage another credential and onboarding is one click.

- TBD
- New visitor signs up via Google in one click
- User denies Google consent and recovers cleanly
- User changes Google email and still resolves to the same MMS account
- Callback missing sub claim is rejected
- Registration page surfaces a Google sign-up entry point — the `/users/register` page renders a `[data-test='google-sign-in']` link to `/auth/google` so a new visitor who lands on registration (not login) can sign up via Google in one click. Currently the button is only on `/users/log-in`; a visitor who clicks "Sign up" from the landing page lands on a magic-link-only registration page with no Google option.

## Story 673 — Sign Up And Sign In With GitHub

As a developer signing up for Market My Spec, I want to sign up and sign in with my GitHub account (mirroring the CodeMySpec auth pattern), so I can use my existing dev identity and skip credential management.

- TBD
- Developer signs up via GitHub in one click
- User cancels GitHub authorization and recovers cleanly
- User with private GitHub email still resolves consistently
- Callback missing GitHub user id is rejected
- Registration page surfaces a GitHub sign-up entry point — the `/users/register` page renders a `[data-test='github-sign-in']` link to `/auth/github` so a new visitor who lands on registration (not login) can sign up via GitHub in one click. Currently the button is only on `/users/log-in`; a visitor who clicks "Sign up" from the landing page lands on a magic-link-only registration page with no GitHub option.

## Story 674 — Start A Marketing Strategy Interview

As a solo founder, I want to start a marketing strategy interview from a fresh chat with my agent — so I get walked through formulating a strategy and end with the artifacts on my local project.

- TBD
- User runs /marketing-strategy in a fresh session and gets oriented
- Skill invocation without bearer is rejected
- Orientation prompt names ./marketing/ and delegates writes to the agent
- Orientation that promises server-side storage is rejected
- User runs /marketing-strategy and the agent loads the playbook
- Slash command invocation without bearer fails clearly
- Agent skims project context before asking the first question
- Skipping orient and asking interview questions cold is rejected
- Restaurant owner gets restaurant examples and one-question cadence
- SaaS-default examples for a non-SaaS user are rejected
- User bails after step 3 and finds three usable artifacts on disk
- Batched end-of-run artifact writes are rejected
- Step 3 dispatches research subagents and grounds personas in evidence
- Persona file with no supporting research artifacts is rejected
- User asks for a blog post and the agent deflects to downstream content
- Agent silently produces a 40-slide deck or sets up analytics is rejected

## Story 675 — Skill Behavior Exposed Over MCP (SSE)

As a connected agent (the user's Claude Code), I want the Market My Spec MCP to expose the marketing-strategy skill's orientation and step prompts as MCP resources/tools (over SSE transport), so I can drive the 8-step interview flow following progressive disclosure — load orientation first, then load each step prompt only when reached.

- TBD
- Agent fetches step 3 and only step 3 lands in context
- Out-of-range step request returns an MCP error
- MCP session initializes over SSE and serves resources
- Plain non-SSE client cannot read resource bodies
- Agent invokes marketing-strategy and receives SKILL.md
- Invoking an unknown skill returns a clear MCP error
- Agent reads step 3 file on demand and only step 3 lands in context
- Reading a non-existent step file returns a not-found error
- Marketing-strategy skill mirrors the canonical plugin file tree
- Skill missing SKILL.md or with synthesized-at-runtime content is rejected
- Path-traversal attempts are rejected before any filesystem read
- Implementation that allows arbitrary reads is rejected by audit

## Story 676 — Strategy Artifacts Saved To My Account

As a user completing the marketing strategy interview, I want my strategy artifacts (current state, jobs/segments, personas, beachhead, positioning, messaging, channels, 90-day plan) persisted to my MMS account workspace as the agent walks me through each step — so I can read them in the MMS web UI, share them with an agency collaborator on the same account, refine them in a future agent session, and never depend on the local filesystem state of the machine I happened to run the interview on. The agent persists each step's artifact through the MMS file API exposed over MCP (story 683); the canonical filename table is preserved across runs so re-running the interview overwrites artifacts in place rather than creating numbered duplicates.

- TBD
- User completes step 5 and finds positioning.md in their repo
- Step prompt without write instructions is rejected
- Re-running the interview overwrites stable filenames, not numbered duplicates
- Random filenames or timestamped variants are rejected
- Step-completion tool call carries only metadata
- Tool call that exfiltrates artifact content is rejected
- Each step file passes the write-instruction audit
- Step file lacking write instruction is rejected by the audit
- Destination filenames match the canonical table
- Drifted filename (e.g., timestamped variant) is rejected
- Tool surface contains only the skill + auth tools, no content sinks
- A new tool with content parameter fails the surface audit
- Skill content sweep finds no hosted-doc language
- Prompt edit introducing "we'll save" is caught by the sweep
- User completes step 5 and finds positioning.md in their project
- Re-running the interview overwrites stable filenames, not numbered duplicates
- Each step file passes the write_file directive audit
- Step file lacking write_file directive is rejected
- Destination filenames match the canonical table
- Drifted filename (e.g., timestamped variant) is rejected
- Skill content sweep finds no local-filesystem language
- Prompt edit introducing local-filesystem language is caught by the sweep
- User completes step 5 and finds positioning.md in their account workspace
- Re-running the interview overwrites stable filenames, not numbered duplicates

## Story 678 — Multi-Tenant Accounts

As a user, I want to create and belong to one or more accounts (workspaces) so that my work is scoped to an account rather than my personal user record, enabling multiple people to collaborate under one account and one person to manage multiple accounts.

Each account has a name, a unique slug, and a type (individual or agency). Users join accounts as members with a role (owner, admin, member). The authenticated user always operates in the context of a current account, and all platform data — MCP connections, strategy artifacts, settings — belongs to the account, not the user.

- New user gets a default individual account on sign-up
- User with no account membership is redirected to account creation
- Account creator is automatically the owner
- Invited user receives exactly one role in the account
- Adding an existing member a second time is rejected
- Two members in the same account see the same MCP connection
- Switching accounts changes the data context
- Account name produces a URL-safe slug on creation
- Duplicate slug is rejected at creation
- Individual account does not show agency features
- Agency account unlocks agency features
- Self-service account creation always produces an individual account
- Admin-provisioned agency account unlocks agency features
- New user is sent to explicit account creation before reaching the dashboard
- User switches accounts via a dedicated account picker page

## Story 679 — Agency Account Type And Client Dashboard

As an agency owner, I want to designate my account as an agency and manage a portfolio of client accounts from a central dashboard, so that I can onboard clients, monitor their status, and navigate between accounts without each client needing to set up independently.

An agency account can create client accounts (originator relationship) or be granted access to existing client accounts (invited relationship). The agency dashboard lists all managed client accounts with their name, status, and the agency's access level. The agency owner can navigate into any client account context from the dashboard.

- Agency user sees the client management dashboard
- Individual account user cannot access the agency dashboard
- Agency creates a client account and becomes the originator
- Originator access grant cannot be revoked
- Client account grants an agency invited access
- Either party can revoke an invited access grant
- Dashboard shows all client accounts with name, status, and access level
- Agency owner enters a client account from the dashboard
- Read-only agency user cannot modify client account settings
- Attempting to grant access for an already-granted agency-client pair is rejected
- Dashboard rows show name and access level only
- Agency team member navigates into a client account
- Dashboard shows all client accounts with name and access level
- Dashboard variant with a status column is rejected

## Story 683 — Agent File Tools Over MCP

As the user's MCP-connected agent (Claude Code, Cursor, Aider, Cline, or any MCP-capable coding/writing assistant), I want Read/Write/Edit-style file tools over MCP — read_file, write_file, edit_file, delete_file, list_files — that operate on artifacts in the user's currently-active account workspace. The tool shape mirrors Claude Code's local file tools so I can use them with no extra prompt scaffolding: write_file creates or overwrites (with read-before-overwrite gating), edit_file does exact-string replacement (with read-before-edit gating), delete_file removes a file (with read-before-delete gating), and list_files returns keys under an optional prefix. The bearer token resolves to one account; relative paths I pass resolve under that account's prefix server-side, so I never see — or have to manage — the account scoping. This is the file-API contract that story 676 (Strategy Artifacts Saved To My Account) builds on top of, and it must work for any MCP-capable agent the user happens to be running.

- tools/list response includes read_file, write_file, edit_file, delete_file, list_files with input schemas matching the Claude Code shape (write_file: {path, content}; edit_file: {path, old_string, new_string, replace_all?}; read_file: {path}; delete_file: {path}; list_files: {prefix?}).
- read_file returns the file body for an existing key under the caller's account prefix; returns a not-found error for missing keys; never reveals keys outside the caller's account.
- write_file with a path that does not yet exist creates the object under the caller's account prefix and returns success; the same path is then readable via read_file in the same session.
- write_file with a path that already exists requires the caller to have read_file'd that path earlier in the same MCP session; without a prior read, the call returns a read-required error and does not overwrite. With a prior read, the call overwrites in place.
- edit_file performs an exact-string replacement of old_string with new_string in the named path; requires a prior read_file of that path in the session; errors if old_string is not unique unless replace_all is true; errors with not-found if the path does not exist.
- delete_file removes the object at the given path under the caller's account prefix; requires a prior read_file of that path in the session; subsequent read_file returns not-found.
- list_files returns the keys under the caller's account prefix (optionally filtered by a relative prefix the caller passes); paths returned are relative — the caller never sees the account-prefix portion of the key.
- Every tool resolves the path under accounts/{account_id}/ on the server using the bearer token's resolved account; a path traversal attempt (../) or any absolute path is rejected, and there is no addressable way for the agent to reach another account's keys.
- tools/list does not include any cross-tenant admin tools, debug tools, or telemetry tools — the file surface is exactly the five primitives plus the skill primitives the project exposes elsewhere.
- tools/list response includes the five file tools with the right shapes
- Adjacent admin or debug tool fails the surface audit
- Relative path resolves under the caller's account prefix server-side
- Path traversal is rejected
- Absolute path is rejected
- Cross-account access is impossible by construction
- read_file returns body for an existing key
- read_file on a missing path returns structured not_found
- write_file on a fresh path creates the object
- write_file on an existing path with prior read overwrites in place
- write_file on existing path without prior read is rejected
- edit_file replaces a unique old_string in a previously-read file
- edit_file with replace_all replaces every occurrence
- edit_file without prior read is rejected
- edit_file with non-unique old_string and no replace_all is rejected
- edit_file on missing path returns not_found
- delete_file after read removes the object
- delete_file without prior read is rejected
- list_files returns relative keys under the caller's account prefix
- list_files with prefix filter narrows the result

## Story 684 — Browse and read account artifacts in a hierarchical files explorer

As a user reviewing my agent's work, I want a single files interface with a hierarchical tree of every artifact my current account has access to on the left and the selected file rendered as styled markdown on the right, so I can navigate and read all my agent's outputs in one place without a separate viewer or guessing at paths.

- `.md` and `.markdown` files render through MDEx with CommonMark + the GFM extensions enabled in the implementation (strikethrough, table, autolink, tasklist, footnotes). A test artifact containing each of those features renders the corresponding HTML element.
- Output is wrapped in `<article class="prose prose-invert max-w-none">` so daisyUI/Tailwind typography styles apply. Visual regression: render a sample artifact and assert the `prose` class appears on a wrapping element.
- Non-markdown files (e.g. `.txt`, `.json`, no extension) fall back to a plain `<pre class="...whitespace-pre-wrap">` block. The server does not invent a rendering for unknown formats.
- MDEx is invoked with `render: [unsafe: false]` so unsafe HTML in source markdown is stripped — a test artifact containing `<script>alert('x')</script>` renders the literal text or an escaped marker, not an executable tag.
- Errors from `Files.get/2` render a user-readable message (`File not available.`), never the raw Elixir error atom. `:no_active_account` redirects to `/accounts` with a flash; other errors stay in place.
- The page title shows the artifact's account-relative key (e.g. `marketing/05_positioning.md`) and includes a Back link to `/files`.
- Rendering is server-side. No client-side markdown library is loaded; viewing an artifact does not depend on JS.
- The `mdex` dep is declared in `mix.exs` and the function `MDEx.to_html!/2` is the canonical entry point — if a future MDEx version renames or removes that function, a compile-time failure surfaces (rather than a runtime crash on first artifact view, like we hit during the 2026-05-04 demo).
- Tree only contains the active account's artifacts
- Direct access to a foreign-account artifact is denied
- Nested paths render as a navigable tree
- Selecting a markdown file renders it styled on the right
- Switching accounts re-scopes the tree and clears stale selection
- Empty account shows an empty-state placeholder
- Selecting a non-markdown file is undefined behavior

## Story 691 — Agency Branding Configuration

As an agency owner, I want to configure my agency's branding — logo URL, primary color, and secondary color — so that when my clients access Market My Spec through my agency's subdomain they see my agency's brand rather than the platform's default branding. Subdomain assignment and host routing is handled by a separate story; this story assumes the agency already has a working subdomain. If branding is unconfigured, clients see the Market My Spec default theme.

- Owner saves all three branding fields
- Member-role user attempts to save branding
- Owner submits an HTTPS logo URL
- Owner submits an HTTP-only logo URL
- Owner submits a malformed logo URL
- Owner submits valid hex colors
- Owner submits a malformed color
- Visitor on a configured agency subdomain sees branding
- Visitor on an unconfigured agency subdomain sees default theme
- Visitor on apex sees default theme regardless of agency configuration
- Visitor on a different agency's subdomain sees that agency's branding only
- Logo URL fails to load in the browser

## Story 695 — Agency Subdomain Assignment and Host Routing

As an agency owner, I want to claim a unique subdomain on marketmyspec.com (e.g. `acme.marketmyspec.com`) so my clients access the platform under my agency's name and the platform's host router resolves the subdomain into my agency's scoped context. The subdomain is the agency's identity on the platform; the agency's branding (logo, colors) is rendered on top of it in a separate story.

- Owner claims an unused subdomain
- Owner attempts to claim a subdomain already taken
- Owner sets a well-formed subdomain
- Owner submits a malformed subdomain
- Owner attempts to claim a reserved subdomain
- Individual account attempts to claim a subdomain
- Admin changes the subdomain
- Member-role user attempts to change the subdomain
- Visitor hits an active agency subdomain
- API call hits the apex domain
- API call hits an agency subdomain
- Visitor lands on the apex domain
- Visitor hits a previously-claimed subdomain after rename
- Visitor hits a never-claimed subdomain
- Visitor hits an unrecognized subdomain
- Visitor hits a former subdomain after the agency renamed

## Story 696 — Invite Members to an Account

As an account owner or admin, I want to send email invitations to teammates and review/cancel pending invitations, so that I can build out the team that has access to my account. Invitees receive a tokenized link that lets them accept and join the account at the role I assigned.

- Owner sends an invitation
- Member-role user cannot invite
- Invitee is already a member
- Email already has a pending invitation
- Invalid email rejected
- Owner sees pending invitations
- Non-member sees nothing
- New user accepts an invitation
- Existing user accepts an invitation
- Invalid or unknown token rejected
- Owner cancels a pending invitation
- Cancelled invitation cannot be accepted
- Expired invitation rejected
- Signed-in matching user accepts
- Signed-in mismatched user blocked
- Invitation expires 7 days after creation

## Story 705 — Discover Reddit engagement opportunities (Thread-backed)

As a solo founder, I want the model to scan Reddit for high-intent engagement opportunities and surface each candidate alongside my prior engagement history — so we can triage across sessions ("we already commented here Tuesday, our angle was X") instead of treating every scan as a cold start.

- LLM can call a `search_engagements` MCP tool with a keyword query and receive a ranked list of candidate threads
- Each candidate carries a stable `thread_id` (UUID), title, source, URL, score, reply_count, recency, and snippet
- The search upserts a Thread row per candidate keyed by (account_id, source, source_thread_id) — re-running the same search updates the existing row, never duplicates
- Thread fields populated on search: score, num_comments, last_activity_at, snippet, title, url, last_seen_at; fetched_at is left untouched (only updated by get_thread)
- Each candidate carries an `engagement` summary: count (integer), latest_state (`:staged | :posted | :abandoned | nil`), latest_angle (string | nil), latest_posted_at (datetime | nil)
- Engagement summary is nil/zero when the Thread has no Touchpoints
- Results are deduplicated and ranking is deterministic given the same query and source state
- A failing source (rate limit, network, auth) degrades gracefully — other sources still return results and the failure is reported in the response
- Search query supports keyword filters; venue/subreddit filtering is available as an optional argument
- Search returns only candidates from the calling account's venues
- Disabled venues are not queried
- Repeat calls with the same query and unchanged venues return identical results (same UUIDs)
- A higher-weight venue's candidate ranks above an equal-signal candidate from a lower-weight venue
- Among same-weight venues, the per-source signal determines order
- Subsequent pages return the next batch via cursor
- Recency reflects time of last activity, not thread creation
- First page returns up to 25 candidates per source
- Re-running the same search updates existing Thread rows instead of duplicating them
- A malformed listing entry is skipped without poisoning the rest of the batch
- Account A's search never surfaces Account B's venues or Threads
- Disabled venues are never queried and never surface candidates
- One venue rate-limited; healthy venue's candidates still surface
- All venues fail; response is empty candidates plus per-venue failure entries
- Higher-weight venue's candidate ranks first; repeat calls return identical UUIDs and ordering
- Engagement summary reflects Touchpoint history; latest by inserted_at; zeroed when none exist
- First page returns 25 candidates plus a cursor; cursor fetches the remainder
- Recency falls back to inserted_at; deep-dived threads use last_activity_at when set

## Story 706 — Refresh a persisted Reddit Thread's full content for the LLM

As a solo founder, I want the model to refresh a Reddit thread's full current content into our persisted record before drafting a reply — so its advice is grounded in what's actually on the page right now, not what we saw on the last scan.

- Agent calls `get_thread(thread_id: UUID)` with a UUID from a prior search response and receives the updated Thread
- Reddit's `/comments/<id>.json` is normalized into `comment_tree` (jsonb) preserving Reddit's response order (confidence/hot at top level, chronological within sub-trees); each comment carries author handle, body, score, created_utc, depth
- `raw_payload` (jsonb) is persisted alongside the normalized form on every successful fetch
- `last_activity_at` is set to the newest comment's created_utc in the tree, or the post's created_utc when there are no comments
- `fetched_at` updates to the call timestamp on every successful fetch
- Within the 5-minute freshness window, a repeat `get_thread` on the same UUID returns the cached row without an HTTP call to Reddit
- Outside the freshness window, `get_thread` re-fetches and updates the same row in place — no new Thread row is created (same UUID)
- Default page caps top-level comments at 25 and the response carries a `comments_cursor` for the next page
- Platform errors (HTTP 429, 5xx, network failure) surface as a usable error response; the persisted Thread row's existing data is preserved (no destructive write on failure)
- Raw payload persists even when normalization partially fails: the row gets `raw_payload` + `fetched_at`, `comment_tree` falls back to its prior value or nil, the normalization error is surfaced in the response
- Cross-account access (UUID owned by a different account) returns `:not_found` and leaks no thread data
- `get_thread` is idempotent within the freshness window — repeat calls produce identical Thread state with no side effects
- Agent calls get_thread on a never-deep-read Thread; full content is fetched and returned
- comment_tree preserves Reddit's order and per-comment fields including depth
- Two refresh calls separated by freshness expiry update the same row in place
- Repeat call within 5-minute window returns cached row without an HTTP call
- Thread with 40 top-level comments returns 25 plus a cursor for the rest
- Outside-window refresh returns 429; response serves stale cached data with a flag
- Reddit returns 200 with malformed comment shape; raw_payload persists, comment_tree falls back to prior
- Account B's call for Account A's Thread returns :not_found and triggers no HTTP

## Story 707 — Stage a Touchpoint from a Thread (synopsis, angle, UTM link)

As a solo founder, when the model has read a thread I'm interested in engaging with, I want it to stage a touchpoint capturing a synopsis of the thread, the angle it would take in a reply, and a UTM-tracked link to the page I'd want to drive readers to — so I have a placeholder ready for me to dictate prose into and the model has a record of its reasoning to reference the next time the thread surfaces.

- Agent stages with synopsis and angle, receives round-trippable Touchpoint id
- Reddit and ElixirForum threads produce distinct utm_source and utm_medium values
- Stage with no campaign override applies the default subreddit:thread-name
- Stage with an explicit utm_campaign persists that value verbatim
- First stage with a synopsis writes that synopsis to the Thread
- A later stage with a different synopsis preserves the original
- Cross-account stage_response returns :not_found and creates no Touchpoint
- stage_response makes zero outbound HTTP calls
- New Touchpoint defaults to state :staged with nil comment_url and posted_at

## Story 708 — Configure venues per source for engagement search

As a solo founder, I want to tell the system which subreddits, forum categories, and tags to search — both via the model through MCP tools and via a manual admin UI — so search results match my ICP without me touching code or restarting the server.

- Venues are persisted with source type (reddit | elixirforum), identifier (subreddit name OR category + optional tag filter), weight (used for ranking), and enabled flag
- LLM can call `add_venue`, `list_venues` (optionally filtered by source), `update_venue`, and `remove_venue` MCP tools
- I can view, add, edit, enable/disable, and remove venues from a LiveView admin page
- Adding a venue validates it against the source's rules (e.g., subreddit name format, ElixirForum category id exists)
- Story 705's search reads the enabled venue list per source and only queries those venues
- The existing slash-command venue lists (r/ClaudeAI, r/ChatGPTCoding, r/vibecoding, r/elixir, r/programming, r/AskProgramming for Reddit; Your Libraries, Phoenix Forum, Chat, Questions/Help for ElixirForum, plus tags ai/llm/testing/bdd/credo) can be seeded on first run
- A denylist (e.g., r/SaaS, r/sideproject) is supported so the system can warn if a venue conflicts with the MMS allocation
- A new Reddit venue persists with all fields
- An ElixirForum venue stores category and optional tag filter
- Weight and enabled flag take sensible defaults
- A valid Reddit subreddit name is accepted
- An invalid Reddit subreddit name is rejected with an error
- An ElixirForum venue with an unknown category is rejected
- The agent creates a venue via add_venue MCP tool
- The agent lists venues, optionally filtered by source
- The agent updates a venue's weight and enabled flag
- The agent removes a venue via remove_venue MCP tool
- Sam views the venue list in the admin LiveView
- Sam adds a new venue from the admin UI
- Sam toggles a venue's enabled flag from the list row
- Sam removes a venue from the admin UI
- Disabling a venue removes it from the next search
- Re-enabling a venue restores it to the search target set
- Each account sees only its own venues
- Cross-account venue access is rejected

## Story 710 — Save and run named keyword searches across venues

As a solo founder, I want to save named keyword-list searches scoped to a chosen subset of my venues, so my agent can re-run a recurring engagement scan by name instead of re-typing the keywords and venue filter every time.

- Sam creates a search scoped to two specific Reddit subreddits
- Sam creates a search scoped to "all ElixirForum"
- Creating a search with empty venue selection is rejected
- Two accounts can each have a search named "elixir testing"
- Renaming a search to a name already taken on the same account fails
- run_search interprets OR alternates and quoted phrases
- A member-role user can create and run a saved search
- Cross-account run_search call returns not_found
- run_search delegates to the shared orchestrator and persists nothing
- Sam manages searches in the admin UI while the agent uses the same surface via MCP

## Story 714 — Add ElixirForum as a second engagement source

As a solo founder, I want the engagement-finder to pull candidates from ElixirForum alongside Reddit — so my list covers both platforms in one scan without me having to choose between them.

- Results are sourced from Reddit and ElixirForum behind a common Source behaviour so adding a third platform later is additive
- Reddit and ElixirForum candidates share the same shape
- One source failing does not poison the other source's results
- All sources failing returns an empty candidate list with per-source failure entries
- Cross-source ordering interleaves per-source ranked lists
- Both adapter modules implement the Source behaviour and the orchestrator dispatches by venue.source
- validate_venue accepts category-slug and category-slug:tag; rejects malformed
- Discourse latest.json normalizes to Thread rows with the canonical field set
- Reddit and ElixirForum candidates in one response have identical key sets
- Reddit 429 plus ElixirForum 200: response has the ElixirForum thread and a Reddit failure entry
- Every venue across every source 5xx: empty candidates plus per-venue failure entries
- High-weight ElixirForum candidate outranks low-weight Reddit candidate with same per-source signal
- Failure entries carry source, venue_identifier, and a human-readable reason

## Story 716 — Touchpoints carry their own angle and explicit lifecycle

As a solo founder, I want every comment I draft on a thread to be a discrete record carrying its own reasoning and an explicit lifecycle state (staged, posted, or abandoned) — so my agent has structured history to lean on when the same thread surfaces again, and I can revise or abandon drafts without losing context.

- Touchpoint schema gains a `state` field with values `:staged | :posted | :abandoned`, defaulting to `:staged` on create
- Touchpoint schema gains an optional `angle` text field for the agent's reasoning on this specific comment
- Existing touchpoints are backfilled: state = :posted where posted_at IS NOT NULL, else :staged
- `stage_response` MCP tool accepts an optional `angle` parameter and persists it on the new touchpoint; angle is not required
- Transitioning a touchpoint to `:posted` requires comment_url and posted_at; the changeset rejects the transition otherwise
- Transitioning a touchpoint to `:abandoned` preserves the row's angle and polished_body — no destructive delete
- New MCP tool `update_touchpoint(touchpoint_id, state, comment_url \\ nil, posted_at \\ nil)` transitions a touchpoint between states
- New MCP tool `list_touchpoints(thread_id)` returns all touchpoints for a thread ordered by inserted_at desc
- `list_touchpoints` payload includes per-touchpoint: id, state, angle, polished_body, comment_url, posted_at, inserted_at
- Cross-account access to a touchpoint via `update_touchpoint` or `list_touchpoints` returns `:not_found` and never leaks data
- The existing LiveView "paste live URL" flow uses the same context function as `update_touchpoint` so UI and agent surfaces transition state identically
- Engagement summary fields on story 705's search candidates are populated from touchpoints with explicit state (no longer inferred from posted_at)
- Touchpoint state moves freely through staged, posted, abandoned, and back
- stage_response persists angle when given; leaves it nil when omitted
- Posted transition with comment_url and posted_at succeeds
- Posted transition without comment_url is rejected; row stays staged
- Abandoning a posted Touchpoint preserves angle, body, comment_url, and posted_at
- LiveView paste-URL flow and update_touchpoint MCP call leave identical persisted state
- list_touchpoints returns all touchpoints newest-first with full metadata
- Account B cannot list, update, or delete Account A's Touchpoints
- Engagement summary trusts the state column even when posted_at conflicts
- delete_touchpoint removes the row; subsequent list does not include it
- TouchpointLive.Show renders the parent thread's `synopsis` when present, displayed above the angle
- TouchpointLive.Show renders `polished_body` in an editable textarea (not readonly) with an explicit "Save" button; submitting calls `Engagements.update_touchpoint/3` and the persisted value matches what was submitted
- TouchpointLive.Show renders `angle` in an editable textarea with the same Save flow as `polished_body`; submitting persists the new angle via `Engagements.update_touchpoint/3`
- TouchpointLive.Show renders the parent thread's `url` as a clickable anchor with `target="_blank"` and `rel="noopener noreferrer"`, positioned near the top of the page for quick navigation to the source platform
- update_touchpoint MCP tool accepts optional polished_body, angle, and state (state no longer required); body/angle edits via the MCP tool persist identically to the LiveView Save form.
- Touchpoint storage columns polished_body, angle, link_target, and comment_url, plus Thread.synopsis, all accept realistic-length values (multi-paragraph bodies, ~600-char agent angle paragraphs, 300+ char Reddit comment URLs with slugs and tracking params) without varchar(255) truncation. Regression guard for the 22001 string_data_right_truncation crash that shipped on 2026-05-17.
- Agent revision propagates to an open touchpoint page without refresh

## Story 731 — Install and pair MMS Agent

As an MMS user, I want to install the MMS Agent binary on my machine and pair it with my MMS account through a one-time browser approval — so I can run Reddit operations from a residential IP where the platform doesn't block them.

- Authenticated user completes pairing
- Anonymous user is challenged to sign in before pairing
- Token is delivered to loopback callback, never rendered in browser
- Fresh state token completes pairing
- Stale or consumed state token is rejected
- URL with state and port renders the approval screen
- Missing state or port renders an error
- Denial creates no Agent and notifies the binary

## Story 732 — MMS Agent connects and reports status

As an MMS user, I want my paired binary to join a per-user Phoenix channel and report its presence so a new Agents page in MMS shows status (online / last-seen / binary version) and downstream features can check whether dispatch is possible.

- Valid token joins the channel
- Invalid or missing token is rejected on join
- Online status appears on Agents page without refresh
- Offline status appears on Agents page without refresh
- Agents page shows binary version and last-connect timestamp
- Agent joins its own user's topic
- Cross-user join is rejected
- Revoked token is refused on rejoin
- Failed join attempt does not flip status to online
- Disconnecting one agent does not flip other agents' status
- Agent that has never connected shows no last-connect timestamp

## Story 733 — Reddit operations route through agent HTTP transport

As an MMS user, I want server-side Reddit operations to execute their HTTP requests through my locally-running agent — so calls originate from my home IP instead of MMS's data-center IP, which Reddit blocks.

- Reddit search dispatches through user's online agent
- Dispatch picks the most recently connected agent
- Allowlisted host is accepted
- Non-allowlisted host is refused before dispatch
- Response within 30s is returned to the caller
- No response within 30s returns a timeout error
- 429 status and Retry-After header are preserved through the agent transport
- ElixirForum HTTP bypasses the agent
- No online agent surfaces user-facing error with link to /agents
- Disconnect mid-flight returns cancellation error before timeout

## Story 736 — Paste a Vale prose-lint configuration onto my account

As a solo founder, I want to paste a Vale configuration into an account settings screen and have it persisted on my Account — so the polish step has a voice and style guide to lint against without me running anything locally.

- Sam pastes a valid .vale.ini and saves it to his Account
- Pasting malformed .vale.ini is rejected; prior configuration unchanged
- Saving a second configuration replaces the first
- Sam clears his Vale configuration and the Account returns to no-config
- Another founder cannot read or modify Sam's Vale configuration

## Story 738 — Polish Touchpoint prose with model help and Vale lint feedback

As a solo founder, once a touchpoint is staged, I want to dictate rough prose to the model and polish the wording back-and-forth with me until we agree — with the model running every draft against my style guide and revising the prose on its own until the linter comes back clean — so the version that lands on the touchpoint is already free of voice and formatting violations without me ever having to read lint output.

- polish_touchpoint writes polished_body onto the named Touchpoint
- Vale lints against the account's saved configuration
- No Vale config on account returns an empty alert list
- Cross-account polish_touchpoint returns :not_found and modifies nothing
- Vale alerts come back as a flat list of agent-friendly entries
- Clean prose writes polished_body and returns no alerts
- Lint alerts block the write and return alerts to the agent