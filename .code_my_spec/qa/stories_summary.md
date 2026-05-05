# Stories

## Story 673 — Sign Up And Sign In With GitHub

As a developer signing up for Market My Spec, I want to sign up and sign in with my GitHub account (mirroring the CodeMySpec auth pattern), so I can use my existing dev identity and skip credential management.

- User cancels GitHub authorization and recovers cleanly
- User with private GitHub email still resolves consistently
- Developer signs up via GitHub in one click
- Callback missing GitHub user id is rejected

## Story 611 — View MCP Connection Instructions

As an authenticated user, I want clear instructions for connecting Market My Spec as an MCP server in Claude Code (server URL, OAuth flow), so I can complete setup without guessing.

- Page missing server URL or install command is rejected
- Anonymous request gets no connection details in the response body
- Signed-in user lands on /mcp-setup with everything they need
- Anonymous visitor is bounced through sign-in to /mcp-setup

## Story 633 — Public Landing Page

As a visitor to the Market My Spec landing page, I want a clear page that explains what Market My Spec does, who it is for (AI-native solo founders), and that it requires bringing my own Claude account, so I can decide whether to sign up without confusion about cost or fit.

- Equal-weight agency CTA next to install is rejected
- Agency visitor finds the Talk-to-John lane below install
- Hero with BYO-Claude warning copy is rejected
- BYO-Claude lives below hero as a benefit line
- Visitor sees a real strategy artifact in the hero
- Hero with no artifact fails the proof-on-page bar
- Draft with banned phrase or enterprise framing is rejected
- Visitor copies install command without an auth gate
- Sign-up gate in front of install command is rejected
- Page passes the messaging-guide phrase audit

## Story 678 — Multi-Tenant Accounts

As a user, I want to create and belong to one or more accounts (workspaces) so that my work is scoped to an account rather than my personal user record, enabling multiple people to collaborate under one account and one person to manage multiple accounts.

Each account has a name, a unique slug, and a type (individual or agency). Users join accounts as members with a role (owner, admin, member). The authenticated user always operates in the context of a current account, and all platform data — MCP connections, strategy artifacts, settings — belongs to the account, not the user.

- User switches accounts via a dedicated account picker page
- Agency account unlocks agency features
- Switching accounts changes the data context
- Duplicate slug is rejected at creation
- Self-service account creation always produces an individual account
- Account creator is automatically the owner
- Admin-provisioned agency account unlocks agency features
- Invited user receives exactly one role in the account
- Account name produces a URL-safe slug on creation
- New user is sent to explicit account creation before reaching the dashboard
- New user gets a default individual account on sign-up
- Individual account does not show agency features
- Two members in the same account see the same MCP connection
- Adding an existing member a second time is rejected
- User with no account membership is redirected to account creation

## Story 675 — Skill Behavior Exposed Over MCP (SSE)

As a connected agent (the user's Claude Code), I want the Market My Spec MCP to expose the marketing-strategy skill's orientation and step prompts as MCP resources/tools (over SSE transport), so I can drive the 8-step interview flow following progressive disclosure — load orientation first, then load each step prompt only when reached.

- Plain non-SSE client cannot read resource bodies
- Agent invokes marketing-strategy and receives SKILL.md
- Invoking an unknown skill returns a clear MCP error
- Reading a non-existent step file returns a not-found error
- Implementation that allows arbitrary reads is rejected by audit
- Path-traversal attempts are rejected before any filesystem read
- Skill missing SKILL.md or with synthesized-at-runtime content is rejected
- Marketing-strategy skill mirrors the canonical plugin file tree
- MCP session initializes over SSE and serves resources
- Agent reads step 3 file on demand and only step 3 lands in context

## Story 672 — Sign Up And Sign In With Google

As a user signing up for Market My Spec, I want to sign up and sign in with my Google account (mirroring the CodeMySpec auth pattern), so I don't have to manage another credential and onboarding is one click.

- Callback missing sub claim is rejected
- New visitor signs up via Google in one click
- User denies Google consent and recovers cleanly
- User changes Google email and still resolves to the same MMS account

## Story 609 — Sign Up And Sign In With Email Magic Link

As a user, I want to sign up and sign in with just my email address using a magic link, so I can get to the interview without remembering a password.

- Invalid email format is caught before submission
- Login page renders only the magic-link form
- Returning user signs in with a fresh magic link
- New visitor signs up via magic link end-to-end
- Direct POST to password endpoint is rejected
- Expired or consumed magic link surfaces a recoverable error

## Story 612 — OAuth Authentication For MCP Connection

As a user installing the Market My Spec MCP, I want to authenticate via OAuth (the same flow CodeMySpec uses), so the server can identify me without me copying tokens, and revocation/rotation are handled by the OAuth provider rather than a custom token-management UI.

- Claude Code completes OAuth and receives a bearer token
- User revokes a token and the MCP endpoint rejects it
- Revoke request with invalid token format is rejected
- Registration request without redirect_uris is rejected
- Metadata document missing endpoints fails discovery
- Token request with bad PKCE verifier is rejected
- Claude Code self-registers as an OAuth client
- MCP client discovers auth server from MCP endpoint URL
- Document missing authorization_servers fails RFC 9728 validation
- MCP request with valid bearer is authenticated
- Expired bearer token returns 401 with re-auth pointer
- MCP client auto-discovers endpoints via well-known metadata

## Story 674 — Start A Marketing Strategy Interview

As a solo founder with the Market My Spec MCP installed in Claude Code, I want to start a marketing strategy interview from a fresh session by invoking the skill, so the agent walks me through the 8-step flow and produces strategy artifacts in my project's local marketing/ directory.

- Persona file with no supporting research artifacts is rejected
- User asks for a blog post and the agent deflects to downstream content
- User runs /marketing-strategy and the agent loads the playbook
- Batched end-of-run artifact writes are rejected
- Slash command invocation without bearer fails clearly
- Agent skims project context before asking the first question
- Skipping orient and asking interview questions cold is rejected
- Restaurant owner gets restaurant examples and one-question cadence
- SaaS-default examples for a non-SaaS user are rejected
- User bails after step 3 and finds three usable artifacts on disk
- Step 3 dispatches research subagents and grounds personas in evidence
- Agent silently produces a 40-slide deck or sets up analytics is rejected

## Story 634 — MCP Setup Guide

As a new user, I want a step-by-step setup guide for installing the Market My Spec MCP in Claude Code (install command, OAuth sign-in, first interview), so I can go from sign-up to interview start without trial and error.

- Page lacking expected-result verification step is rejected
- User hits port conflict and recovers via troubleshooting block
- Page missing one of the three required troubleshooting blocks is rejected
- New user follows guide top-to-bottom and ships first interview

## Story 679 — Agency Account Type And Client Dashboard

As an agency owner, I want to designate my account as an agency and manage a portfolio of client accounts from a central dashboard, so that I can onboard clients, monitor their status, and navigate between accounts without each client needing to set up independently.

An agency account can create client accounts (originator relationship) or be granted access to existing client accounts (invited relationship). The agency dashboard lists all managed client accounts with their name, status, and the agency's access level. The agency owner can navigate into any client account context from the dashboard.

- Originator access grant cannot be revoked
- Attempting to grant access for an already-granted agency-client pair is rejected
- Individual account user cannot access the agency dashboard
- Client account grants an agency invited access
- Dashboard variant with a status column is rejected
- Agency team member navigates into a client account
- Either party can revoke an invited access grant
- Dashboard rows show name and access level only
- Dashboard shows all client accounts with name and access level
- Read-only agency user cannot modify client account settings
- Agency user sees the client management dashboard
- Agency owner enters a client account from the dashboard
- Agency creates a client account and becomes the originator

## Story 676 — Strategy Artifacts Saved To My Account

As a user completing the marketing strategy interview, I want my strategy artifacts (current state, jobs/segments, personas, beachhead, positioning, messaging, channels, 90-day plan) persisted to my MMS account workspace as the agent walks me through each step — so I can read them in the MMS web UI, share them with an agency collaborator on the same account, refine them in a future agent session, and never depend on the local filesystem state of the machine I happened to run the interview on. The agent persists each step's artifact through the MMS file API exposed over MCP (story 683); the canonical filename table is preserved across runs so re-running the interview overwrites artifacts in place rather than creating numbered duplicates.

- User completes step 5 and finds positioning.md in their account workspace
- Re-running the interview overwrites stable filenames, not numbered duplicates
- Drifted filename (e.g., timestamped variant) is rejected
- Prompt edit introducing "we'll save" is caught by the sweep
- Step file lacking write_file directive is rejected
- Destination filenames match the canonical table
- Step file lacking write instruction is rejected by the audit
- Tool surface contains only the skill + auth tools, no content sinks
- Skill content sweep finds no local-filesystem language
- Prompt edit introducing local-filesystem language is caught by the sweep
- Re-running the interview overwrites stable filenames, not numbered duplicates
- Destination filenames match the canonical table
- Each step file passes the write_file directive audit
- Drifted filename (e.g., timestamped variant) is rejected
- A new tool with content parameter fails the surface audit
- Each step file passes the write-instruction audit
- User completes step 5 and finds positioning.md in their project
- Skill content sweep finds no hosted-doc language

## Story 683 — Agent File Tools Over MCP

As the user's MCP-connected agent (Claude Code, Cursor, Aider, Cline, or any MCP-capable coding/writing assistant), I want Read/Write/Edit-style file tools over MCP — read_file, write_file, edit_file, delete_file, list_files — that operate on artifacts in the user's currently-active account workspace. The tool shape mirrors Claude Code's local file tools so I can use them with no extra prompt scaffolding: write_file creates or overwrites (with read-before-overwrite gating), edit_file does exact-string replacement (with read-before-edit gating), delete_file removes a file (with read-before-delete gating), and list_files returns keys under an optional prefix. The bearer token resolves to one account; relative paths I pass resolve under that account's prefix server-side, so I never see — or have to manage — the account scoping. This is the file-API contract that story 676 (Strategy Artifacts Saved To My Account) builds on top of, and it must work for any MCP-capable agent the user happens to be running.

- write_file with a path that already exists requires the caller to have read_file'd that path earlier in the same MCP session; without a prior read, the call returns a read-required error and does not overwrite. With a prior read, the call overwrites in place.
- Path traversal is rejected
- edit_file performs an exact-string replacement of old_string with new_string in the named path; requires a prior read_file of that path in the session; errors if old_string is not unique unless replace_all is true; errors with not-found if the path does not exist.
- tools/list does not include any cross-tenant admin tools, debug tools, or telemetry tools — the file surface is exactly the five primitives plus the skill primitives the project exposes elsewhere.
- delete_file removes the object at the given path under the caller's account prefix; requires a prior read_file of that path in the session; subsequent read_file returns not-found.
- list_files returns the keys under the caller's account prefix (optionally filtered by a relative prefix the caller passes); paths returned are relative — the caller never sees the account-prefix portion of the key.
- Absolute path is rejected
- read_file returns body for an existing key
- edit_file with replace_all replaces every occurrence
- edit_file without prior read is rejected
- list_files with prefix filter narrows the result
- write_file on a fresh path creates the object
- write_file on an existing path with prior read overwrites in place
- edit_file on missing path returns not_found
- list_files returns relative keys under the caller's account prefix
- Every tool resolves the path under accounts/{account_id}/ on the server using the bearer token's resolved account; a path traversal attempt (../) or any absolute path is rejected, and there is no addressable way for the agent to reach another account's keys.
- delete_file after read removes the object
- tools/list response includes read_file, write_file, edit_file, delete_file, list_files with input schemas matching the Claude Code shape (write_file: {path, content}; edit_file: {path, old_string, new_string, replace_all?}; read_file: {path}; delete_file: {path}; list_files: {prefix?}).
- tools/list response includes the five file tools with the right shapes
- Adjacent admin or debug tool fails the surface audit
- Relative path resolves under the caller's account prefix server-side
- Cross-account access is impossible by construction
- read_file on a missing path returns structured not_found
- delete_file without prior read is rejected
- write_file on existing path without prior read is rejected
- edit_file replaces a unique old_string in a previously-read file
- edit_file with non-unique old_string and no replace_all is rejected
- read_file returns the file body for an existing key under the caller's account prefix; returns a not-found error for missing keys; never reveals keys outside the caller's account.
- write_file with a path that does not yet exist creates the object under the caller's account prefix and returns success; the same path is then readable via read_file in the same session.