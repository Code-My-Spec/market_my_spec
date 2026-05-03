# Architecture Proposal

Market My Spec exposes a single marketing-strategy skill over MCP (SSE transport) to a connected agent. The web app handles sign-up, MCP setup guidance, and OAuth consent. Domain layer splits into Users (web identity), Integrations (Google/GitHub OAuth sign-in), McpAuth (OAuth server for MCP clients), and Skills (the marketing-strategy skill content).

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

- MarketMySpec.Accounts.Account (schema) [Stories: 678]: Account record — name, slug, type (individual/agency)
- MarketMySpec.Accounts.Member (schema) [Stories: 678]: User-to-account membership with role
- MarketMySpec.Accounts.AccountsRepository (module) [Stories: 678]: Account CRUD and membership queries
- MarketMySpec.Accounts.MembersRepository (module) [Stories: 678]: Member-specific queries
- MarketMySpec.Accounts.Invitation (schema) [Stories: 678]: Pending membership invitations
- MarketMySpec.Accounts.InvitationRepository (module) [Stories: 678]: Invitation CRUD
- MarketMySpec.Accounts.InvitationNotifier (module) [Stories: 678]: Sends invitation emails via Swoosh
- MarketMySpec.Authorization (module) [Stories: 678]: Role-based permission checks used across contexts

### MarketMySpec.Agencies

- **Type:** context
- **Description:** Agency account type and client account management. Agency accounts can create client accounts (originator relationship), view their client portfolio, and navigate into client contexts. Access grants link agency accounts to client accounts with a permission level.
- **Stories:** 679

#### Children

- MarketMySpec.Agencies.AgencyClientAccessGrant (schema) [Stories: 679]: Agency-to-client access record — access_level, origination_status (originator/invited)
- MarketMySpec.Agencies.AgenciesRepository (module) [Stories: 679]: Create client accounts (originator path), record invited access grants, query portfolio of client accounts for a given agency

### MarketMySpec.Skills

- **Type:** context
- **Description:** Marketing-strategy skill content. Defines the orientation prompt and the eight step prompts the user's agent loads progressively via MCP. Also exposes public-facing marketing copy for the landing page.
- **Stories:** 674, 675, 676, 633

#### Children

- MarketMySpec.Skills.MarketingStrategy (module) [Stories: 674, 675, 676]: The skill — orientation prompt, eight step prompts, artifact write instructions for the agent
- MarketMySpec.Skills.Overview (module) [Stories: 633]: Public marketing copy describing the skill (value prop, BYO-Claude requirement, who it is for) consumed by HomeLive

## Surface Components

### MarketMySpecWeb.AccountsLive

- **Type:** live_context
- **Description:** Account management views — create first account, list accounts, manage settings, and members. Includes the account picker used when switching between accounts.
- **Stories:** 678

#### Children

- MarketMySpecWeb.AccountsLive.Index (liveview) [Stories: 678]: List all accounts the user belongs to
- MarketMySpecWeb.AccountsLive.Picker (liveview) [Stories: 678]: Account switcher — select current account context
- MarketMySpecWeb.AccountsLive.Form (liveview) [Stories: 678]: Create a new account (name only, type defaults to individual)
- MarketMySpecWeb.AccountsLive.Manage (liveview) [Stories: 678]: Account settings
- MarketMySpecWeb.AccountsLive.Members (liveview) [Stories: 678]: Member list and role management

### MarketMySpecWeb.InvitationsLive

- **Type:** live_context
- **Description:** Invitation management views — invite new members to an account and manage pending invitations.
- **Stories:** 678

#### Children

- MarketMySpecWeb.InvitationsLive.Index (liveview) [Stories: 678]: List pending invitations for the current account
- MarketMySpecWeb.InvitationsLive.New (liveview) [Stories: 678]: Send a new member invitation by email

### MarketMySpecWeb.AgencyLive

- **Type:** live_context
- **Description:** Agency client management views — available only to agency-type accounts. Dashboard lists all client accounts the agency has access to. Agency users can navigate into any client account context from here.
- **Stories:** 679

#### Children

- MarketMySpecWeb.AgencyLive.Dashboard (liveview) [Stories: 679]: Client portfolio dashboard — lists client accounts with name and agency access level; enter-client action switches current account context

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
- **Description:** MCP server endpoint mounting Anubis MCP. Validates the bearer token (issued by McpAuth), then handles JSON-RPC requests over POST and the long-lived SSE stream. Exposes the marketing-strategy skill's orientation/steps as MCP resources and an artifact-tracking tool the agent calls when each step is completed.
- **Stories:** 674, 675, 676

## Dependencies

- MarketMySpecWeb.HomeLive -> MarketMySpec.Skills
- MarketMySpecWeb.UserLive -> MarketMySpec.Users
- MarketMySpecWeb.UserLive -> MarketMySpec.Integrations
- MarketMySpecWeb.McpSetupLive -> MarketMySpec.McpAuth
- MarketMySpecWeb.McpAuthorizationLive -> MarketMySpec.McpAuth
- MarketMySpecWeb.McpAuthorizationLive -> MarketMySpec.Users
- MarketMySpecWeb.McpController -> MarketMySpec.McpAuth
- MarketMySpecWeb.McpController -> MarketMySpec.Skills
- MarketMySpec.McpAuth -> MarketMySpec.Users
- MarketMySpec.Integrations -> MarketMySpec.Users
- MarketMySpecWeb.AccountsLive -> MarketMySpec.Accounts
- MarketMySpecWeb.AccountsLive -> MarketMySpec.Users
- MarketMySpecWeb.InvitationsLive -> MarketMySpec.Accounts
- MarketMySpecWeb.InvitationsLive -> MarketMySpec.Users
- MarketMySpecWeb.AgencyLive -> MarketMySpec.Agencies
- MarketMySpecWeb.AgencyLive -> MarketMySpec.Accounts
- MarketMySpec.Agencies -> MarketMySpec.Accounts
