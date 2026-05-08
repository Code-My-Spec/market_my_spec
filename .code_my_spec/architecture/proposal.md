# Architecture Proposal

Market My Spec exposes a single marketing-strategy skill over MCP (SSE transport) to a connected agent. The web app handles sign-up, MCP setup guidance, and OAuth consent. Domain layer splits into Users (web identity), Integrations (Google/GitHub OAuth sign-in), McpAuth (OAuth server for MCP clients), Skills (the marketing-strategy skill content), Accounts (multi-tenant workspaces), Agencies (agency account type, agency-client grants, subdomain routing), and Files (account-scoped file storage for skill artifacts).

## Contexts

### MarketMySpec.Users

- **Type:** context
- **Description:** User identity and authentication. Magic-link sign-in via email; user records, tokens, and authentication scope.
- **Stories:** 609

#### Children

- MarketMySpec.Users.User (schema) [Stories: 609]: User account record
- MarketMySpec.Users.UserToken (schema) [Stories: 609]: Auth + magic-link tokens
- MarketMySpec.Users.Scope (module) [Stories: 609]: Auth scope wrapper passed through LiveViews
- MarketMySpec.Users.UserNotifier (module) [Stories: 609]: Sends magic-link emails via Swoosh

### MarketMySpec.Integrations

- **Type:** context
- **Description:** OAuth provider integrations for sign-in identity capture. Wraps Assent strategies for Google and GitHub; persists user-provider linkage with encrypted token storage.
- **Stories:** 672, 673

#### Children

- MarketMySpec.Integrations.Integration (schema) [Stories: 672, 673]: Per-user-per-provider OAuth record with encrypted access/refresh tokens
- MarketMySpec.Integrations.IntegrationRepository (module) [Stories: 672, 673]: Upsert/fetch/list operations on integrations
- MarketMySpec.Integrations.Providers.Google (module) [Stories: 672]: Google OAuth provider config + user normalization
- MarketMySpec.Integrations.Providers.GitHub (module) [Stories: 673]: GitHub OAuth provider config + user normalization
- MarketMySpec.Integrations.Providers.Behaviour (module): Provider behaviour contract

### MarketMySpec.McpAuth

- **Type:** context
- **Description:** OAuth 2.0 authorization server for MCP clients. Wraps ex_oauth2_provider so the user's Claude Code (or other MCP client) can authenticate via auth-code + PKCE and receive a bearer token used to call the MCP endpoint. Distinct from web-side sign-in.
- **Stories:** 612, 611, 634

#### Children

- MarketMySpec.McpAuth.Authorization (module) [Stories: 612]: Wraps the OAuth authorization-grant flow — validates PKCE challenges, builds consent context, issues codes
- MarketMySpec.McpAuth.Token (module) [Stories: 612]: Wraps the OAuth token endpoint — exchanges codes for access tokens, validates bearer tokens for MCP requests
- MarketMySpec.McpAuth.ConnectionInfo (module) [Stories: 611, 634]: Builds setup-guide payload (server URL, OAuth flow steps, install command) consumed by McpSetupLive

### MarketMySpec.Accounts

- **Type:** context
- **Description:** Multi-tenant account workspaces. Accounts scope all platform data. Users belong to accounts with roles (owner, admin, member). Provides account creation, membership management, and the Scope struct used throughout the app.
- **Stories:** 678

#### Children

- MarketMySpec.Accounts.Account (schema) [Stories: 678, 691, 695]: Account record — name, slug, type (individual/agency); for agency-typed accounts also holds subdomain (story 695) and branding fields — logo_url, primary_color, secondary_color (story 691)
- MarketMySpec.Accounts.Member (schema) [Stories: 678]: User-to-account membership with role
- MarketMySpec.Accounts.AccountsRepository (module) [Stories: 678]: Account CRUD and membership queries
- MarketMySpec.Accounts.MembersRepository (module) [Stories: 678]: Member-specific queries
- MarketMySpec.Accounts.Invitation (schema) [Stories: 678]: Pending membership invitations
- MarketMySpec.Accounts.InvitationRepository (module) [Stories: 678]: Invitation CRUD
- MarketMySpec.Accounts.InvitationNotifier (module) [Stories: 678]: Sends invitation emails via Swoosh

### MarketMySpec.Agencies

- **Type:** context
- **Description:** Agency account type, client account management, and agency identity (subdomain + branding). Agency accounts can create client accounts (originator relationship), view their client portfolio, and navigate into client contexts. Access grants link agency accounts to client accounts with a permission level. Also handles agency subdomain claiming/host resolution and agency branding configuration.
- **Stories:** 679, 691, 695

#### Children

- MarketMySpec.Agencies.AgencyClientAccessGrant (schema) [Stories: 679]: Agency-to-client access record — access_level, origination_status (originator/invited)
- MarketMySpec.Agencies.AgenciesRepository (module) [Stories: 679, 691]: Create client accounts (originator path), record invited access grants, query portfolio of client accounts for a given agency, update agency branding fields
- MarketMySpec.Agencies.HostResolver (module) [Stories: 695]: Resolves a request host to an agency account by subdomain match; validates subdomain format and uniqueness on claim; updates an agency's subdomain

### MarketMySpec.Files

- **Type:** context
- **Description:** Account-scoped file storage for skill artifacts. Files written by the user's MCP-connected agent through the marketing-strategy skill's tools land here, scoped to the active account's prefix. Behaviour-backed so the storage backend is configurable (S3 in prod/UAT, disk in dev, in-memory in test).
- **Stories:** 683, 684

#### Children

- MarketMySpec.Files.Behaviour (module) [Stories: 683, 684]: Storage behaviour contract — put/get/list/delete with account-scoped keys
- MarketMySpec.Files.S3 (module) [Stories: 683, 684]: S3 implementation of the Files behaviour; default backend in UAT/prod
- MarketMySpec.Files.Disk (module) [Stories: 683, 684]: Local-disk implementation of the Files behaviour; used in dev
- MarketMySpec.Files.Memory (module) [Stories: 683, 684]: In-memory implementation of the Files behaviour; used in test

### MarketMySpec.Skills

- **Type:** context
- **Description:** Marketing-strategy skill content. Defines the orientation prompt and the eight step prompts the user's agent loads progressively via MCP. Also exposes public-facing marketing copy for the landing page.
- **Stories:** 674, 675, 676, 633

#### Children

- MarketMySpec.Skills.MarketingStrategy (module) [Stories: 674, 675, 676]: The skill — orientation prompt, eight step prompts, artifact write instructions for the agent
- MarketMySpec.Skills.Overview (module) [Stories: 633]: Public marketing copy describing the skill (value prop, BYO-Claude requirement, who it is for) consumed by HomeLive

## Surface Components

### MarketMySpecWeb.AccountLive

- **Type:** live_context
- **Description:** Account management views — create first account, list accounts, manage settings, and members. Includes the account picker used when switching between accounts.
- **Stories:** 678

#### Children

- MarketMySpecWeb.AccountLive.Index (liveview) [Stories: 678]: List all accounts the user belongs to
- MarketMySpecWeb.AccountLive.Picker (liveview) [Stories: 678]: Account switcher — select current account context
- MarketMySpecWeb.AccountLive.Form (liveview) [Stories: 678]: Create a new account (name only, type defaults to individual)
- MarketMySpecWeb.AccountLive.Manage (liveview) [Stories: 678]: Account settings
- MarketMySpecWeb.AccountLive.Members (liveview) [Stories: 678]: Member list and role management

### MarketMySpecWeb.InvitationsLive

- **Type:** live_context
- **Description:** Invitation management views — invite new members to an account and manage pending invitations. Reached transitively from AccountLive (the account management surface that owns story 678).
- **Stories:**

#### Children

- MarketMySpecWeb.InvitationsLive.Index (liveview): List pending invitations for the current account
- MarketMySpecWeb.InvitationsLive.New (liveview): Send a new member invitation by email

### MarketMySpecWeb.AgencyLive

- **Type:** live_context
- **Description:** Agency views available only to agency-typed accounts. Dashboard lists managed clients; settings let the agency owner claim a subdomain and configure branding (logo URL + primary/secondary colors).
- **Stories:** 679, 691, 695

#### Children

- MarketMySpecWeb.AgencyLive.Dashboard (liveview) [Stories: 679]: Client portfolio dashboard — lists client accounts with name and agency access level; enter-client action switches current account context
- MarketMySpecWeb.AgencyLive.Settings (liveview) [Stories: 691, 695]: Agency settings form — owner sets/changes the agency's unique subdomain (story 695) and branding fields (logo URL + primary/secondary colors, story 691); validates format/uniqueness; renders saved values prefilled on reload

### MarketMySpecWeb.FilesLive

- **Type:** live_context
- **Description:** Account-scoped file browser. Surfaces artifacts the user's agent has written into the account via MCP file tools, with a hierarchical tree view and rendered file content.
- **Stories:** 684

#### Children

- MarketMySpecWeb.FilesLive.Browser (liveview) [Stories: 684]: List artifacts for the current account in a file hierarchy; selecting a file displays its rendered content alongside the tree

### MarketMySpecWeb.HomeLive

- **Type:** liveview
- **Description:** Public landing page. Explains what Market My Spec does, who it's for (AI-native solo founders), the BYO-Claude requirement, and the sign-up CTA. Replaces the default PageController route.
- **Stories:** 633

### MarketMySpecWeb.UserLive

- **Type:** live_context
- **Description:** Authentication UI scaffolded by phx.gen.auth — login (magic-link form + OAuth buttons), registration, settings, magic-link confirmation.
- **Stories:** 609, 672, 673

#### Children

- MarketMySpecWeb.UserLive.Login (liveview) [Stories: 609, 672, 673]: Sign-in screen with magic-link form and Google/GitHub OAuth buttons
- MarketMySpecWeb.UserLive.Registration (liveview) [Stories: 609]: Email-based sign-up
- MarketMySpecWeb.UserLive.Confirmation (liveview) [Stories: 609]: Magic-link token confirmation
- MarketMySpecWeb.UserLive.Settings (liveview): Account settings

### MarketMySpecWeb.McpSetupLive

- **Type:** liveview
- **Description:** Authenticated MCP setup guide. Step-by-step instructions for installing the MCP plugin in Claude Code, completing OAuth sign-in, and starting the first interview. Pulls server URL and OAuth flow details from McpAuth.ConnectionInfo.
- **Stories:** 611, 634

### MarketMySpecWeb.McpAuthorizationLive

- **Type:** liveview
- **Description:** OAuth 2.0 consent screen. When an MCP client requests authorization, this LiveView shows the user what scopes are being granted and captures approve/deny. Posts back to the OAuth authorization endpoint with the user's decision.
- **Stories:** 612

### MarketMySpecWeb.McpController

- **Type:** controller
- **Description:** MCP server endpoint mounting Anubis MCP. Validates the bearer token (issued by McpAuth), then handles JSON-RPC requests over POST and the long-lived SSE stream. Exposes the marketing-strategy skill's orientation/steps as MCP resources, an artifact-tracking tool the agent calls when each step is completed, and account-scoped file tools (read/write/edit/delete/list) the agent uses to produce skill artifacts.
- **Stories:** 674, 675, 676, 683

### MarketMySpecWeb.Plugs.AgencyHost

- **Type:** module
- **Description:** Endpoint plug that reads the request host. If the host is `<slug>.marketmyspec.com` and an agency currently claims that subdomain, attaches the agency to the conn for downstream LiveViews. Apex requests pass through unchanged. Unrecognized subdomains redirect to the apex. API endpoints (`/oauth/*`, `/mcp`, `/.well-known/*`) are skipped — they remain apex-only.
- **Stories:** 695

## Dependencies

- MarketMySpecWeb.HomeLive -> MarketMySpec.Skills
- MarketMySpecWeb.UserLive -> MarketMySpec.Users
- MarketMySpecWeb.UserLive -> MarketMySpec.Integrations
- MarketMySpecWeb.McpSetupLive -> MarketMySpec.McpAuth
- MarketMySpecWeb.McpAuthorizationLive -> MarketMySpec.McpAuth
- MarketMySpecWeb.McpAuthorizationLive -> MarketMySpec.Users
- MarketMySpecWeb.McpController -> MarketMySpec.McpAuth
- MarketMySpecWeb.McpController -> MarketMySpec.Skills
- MarketMySpecWeb.McpController -> MarketMySpec.Files
- MarketMySpec.McpAuth -> MarketMySpec.Users
- MarketMySpec.Integrations -> MarketMySpec.Users
- MarketMySpecWeb.AccountLive -> MarketMySpec.Accounts
- MarketMySpecWeb.AccountLive -> MarketMySpec.Users
- MarketMySpecWeb.AccountLive -> MarketMySpecWeb.InvitationsLive
- MarketMySpecWeb.InvitationsLive -> MarketMySpec.Accounts
- MarketMySpecWeb.InvitationsLive -> MarketMySpec.Users
- MarketMySpecWeb.AgencyLive -> MarketMySpec.Agencies
- MarketMySpecWeb.AgencyLive -> MarketMySpec.Accounts
- MarketMySpecWeb.FilesLive -> MarketMySpec.Files
- MarketMySpecWeb.FilesLive -> MarketMySpec.Accounts
- MarketMySpecWeb.Plugs.AgencyHost -> MarketMySpec.Agencies
- MarketMySpec.Agencies -> MarketMySpec.Accounts
- MarketMySpec.Files -> MarketMySpec.Accounts
