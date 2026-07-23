# Multi-Tenant Accounts

As a user, I want to create and belong to one or more accounts (workspaces) so that my work is scoped to an account rather than my personal user record, enabling multiple people to collaborate under one account and one person to manage multiple accounts.

Each account has a name, a unique slug, and a type (individual or agency). Users join accounts as members with a role (owner, admin, member). The authenticated user always operates in the context of a current account, and all platform data — MCP connections, strategy artifacts, settings — belongs to the account, not the user.

## Meta
- id: 90f19de5-b5ef-428a-8ab5-a29c5c1c4bb3
- number: 678
- status: in_progress
- component: MarketMySpecWeb.AccountLive.Members
- personas: agency-owner, founder

## Rules

### A user must belong to at least one account before they can access any platform features

#### happy: New user gets a default individual account on sign-up [28f65948]
Given a new user completes sign-up via magic link
When the authentication flow completes
Then a default individual account is automatically created for that user
And the user is assigned the owner role on that account
And the user lands on the platform dashboard scoped to that account

#### failure: User with no account membership is redirected to account creation [bd55e5bc]
Given an authenticated user exists who belongs to no accounts
When they navigate to any protected route
Then they are redirected to the account creation page
And the dashboard is not rendered

#### happy: New user is sent to explicit account creation before reaching the dashboard [daa31f9f]
Given a new user has just completed sign-up
When their session is established
Then they are redirected to a "Create your account" page
And the page asks for an account name only (type defaults to individual, no selector shown)
And on submit they are taken to the dashboard scoped to their new account

### The user who creates an account is automatically assigned the owner role

#### happy: Account creator is automatically the owner [891b9e53]
Given an authenticated user
When they create a new account named "Acme Agency"
Then an account_members record is created for that user on the new account
And the role on that record is "owner"

### A user holds exactly one role within a given account (owner, admin, or member)

#### happy: Invited user receives exactly one role in the account [bd0eac59]
Given an account owner invites a colleague by email with role "member"
When the colleague accepts the invitation and signs in
Then a single account_members record exists for that user on the account
And the role is "member"

#### failure: Adding an existing member a second time is rejected [18561479]
Given a user is already a member of an account
When an admin attempts to add the same user to the same account again
Then the operation is rejected with a conflict error
And no duplicate account_members record is created

### All platform data — MCP connections, strategy artifacts, and settings — belongs to the account, not the individual user

#### happy: Two members in the same account see the same MCP connection [4deaf89a]
Given user A and user B are both members of "Acme Agency" account
And user A creates an MCP connection while in that account context
When user B navigates to the MCP connections page in the same account context
Then user B sees the connection created by user A

### A user with multiple accounts operates within exactly one current account context at a time; all reads and writes are scoped to that context

#### happy: Switching accounts changes the data context [71412edc]
Given a user belongs to both "Personal" account and "Acme Agency" account
And they are currently in the "Personal" account context
When they switch to the "Acme Agency" account context
Then the dashboard, MCP connections, and strategy artifacts shown are those belonging to "Acme Agency"
And "Personal" account data is no longer visible

#### happy: User switches accounts via a dedicated account picker page [2b26564f]
Given a user belongs to both "Personal" and "Acme Agency" accounts
When they navigate to the account picker page
Then they see a list of all accounts they belong to
And selecting "Acme Agency" sets it as the current context and redirects to the dashboard
And all subsequent reads and writes are scoped to "Acme Agency"

### Account slugs are globally unique and URL-safe; once set they cannot be changed

#### happy: Account name produces a URL-safe slug on creation [86192068]
Given a user creates an account with the name "Acme Agency"
When the account is saved
Then the slug is set to "acme-agency"
And the slug contains only lowercase letters, numbers, and hyphens

#### failure: Duplicate slug is rejected at creation [6ade3dca]
Given an account with slug "acme-agency" already exists
When a different user tries to create an account that would produce the same slug
Then the creation is rejected with a uniqueness error
And no account record is created

### Account type (individual or agency) is fixed at creation and gates which features are available to that account

#### happy: Individual account does not show agency features [7841c5da]
Given a user creates an account with type "individual"
When they navigate the platform
Then the agency management dashboard is not present in the navigation
And no agency-specific settings are accessible

#### happy: Agency account unlocks agency features [3913d676]
Given a user creates an account with type "agency"
When they navigate the platform
Then the agency management dashboard is accessible in the navigation
And white label settings are accessible in account settings

#### happy: Self-service account creation always produces an individual account [17045962]
Given a user completes the "create your first account" form with a name
When the account is saved
Then the account type is set to "individual"
And no agency type selector is shown on the form

### Agency accounts are admin-provisioned only; the self-service account creation form produces individual accounts exclusively — users cannot self-select the agency type

#### happy: Admin-provisioned agency account unlocks agency features [835dc966]
Given an admin has provisioned an agency account for a user
When that user signs in and selects the agency account context
Then the agency management dashboard is accessible in the navigation
And white label settings are accessible in account settings

## Questions
- [resolved] On sign-up, does a default individual account auto-create silently, or does the user go through an explicit "create your first account" step? The happy-path scenario assumes silent auto-creation — confirm this is the intended UX before implementing.
- [resolved] Can an account owner change account type from individual to agency after creation? The rule says type is fixed at creation — but if an existing solo user wants to upgrade to agency, what's the path?
- [resolved] What is the UX for account switching when a user belongs to multiple accounts — a nav dropdown, a separate accounts landing page, or per-account URLs (e.g. /accounts/:slug)?
- [resolved] Existing users have no account record. When multi-tenancy lands, does a migration backfill a default individual account for every existing user, or is a manual onboarding step required?
