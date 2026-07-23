# Agency Account Type And Client Dashboard

As an agency owner, I want to designate my account as an agency and manage a portfolio of client accounts from a central dashboard, so that I can onboard clients, monitor their status, and navigate between accounts without each client needing to set up independently.

An agency account can create client accounts (originator relationship) or be granted access to existing client accounts (invited relationship). The agency dashboard lists all managed client accounts with their name, status, and the agency's access level. The agency owner can navigate into any client account context from the dashboard.

## Meta
- id: 6e534eb4-158e-4424-8c4a-c850f6758d79
- number: 679
- status: in_progress
- component: MarketMySpecWeb.AgencyLive
- personas: agency-owner, founder

## Rules

### Only agency-type accounts have access to the client management dashboard

#### happy: Agency user sees the client management dashboard [2ebc0735]
Given a user is operating in an agency-type account context
When they navigate to the agency client dashboard
Then the dashboard renders with their portfolio of client accounts

#### failure: Individual account user cannot access the agency dashboard [9ec5005a]
Given a user is operating in an individual-type account context
When they attempt to navigate to the agency client dashboard
Then they receive a 403 or are redirected away
And the dashboard is not rendered

### When an agency creates a client account, the agency is recorded as the originator, establishing a permanent access grant that cannot be revoked

#### happy: Agency creates a client account and becomes the originator [00bb5fe0]
Given a user is operating in an agency account context
When they create a new client account named "Bright Ideas Co"
Then a new account is created with type "individual"
And an agency_client_access_grant record is created linking the agency to the new account
And the grant's origination_status is "originator"
And the new client account appears on the agency dashboard

#### failure: Originator access grant cannot be revoked [37be99a1]
Given an agency has an originator access grant on a client account
When any party attempts to revoke that grant
Then the operation is rejected with an error
And the access grant remains in place

### An existing client account can grant an agency access by invitation; this invited relationship can be revoked by either party

#### happy: Client account grants an agency invited access [f7d03d5e]
Given an existing client account and an existing agency account
When the client account owner grants the agency access at level "account_manager"
Then an agency_client_access_grant is created with origination_status "invited" and access_level "account_manager"
And the client account appears on the agency's dashboard

#### happy: Either party can revoke an invited access grant [96a62021]
Given an agency has an invited access grant on a client account
When either the agency owner or the client account owner revokes the grant
Then the agency_client_access_grant record is deleted
And the client account no longer appears on the agency's dashboard

### Navigating into a client account from the dashboard sets that account as the user's current account context

#### happy: Agency owner enters a client account from the dashboard [9d3fd7a2]
Given an agency owner is viewing the client dashboard
When they click to enter "Bright Ideas Co"
Then the current account context is set to "Bright Ideas Co"
And they are redirected to the dashboard scoped to that client account
And a visual indicator shows they are operating inside a client account

### The agency's access level on a client account (read_only, account_manager, or admin) governs what actions the agency user can perform within that client context

#### happy: Read-only agency user cannot modify client account settings [22ae7f4e]
Given an agency has read_only access to a client account
When an agency team member operates inside that client account context
Then they can view strategy artifacts and settings
But they cannot create, edit, or delete any data within the client account

### An agency account can have at most one access grant per client account — duplicate grants for the same agency-client pair are rejected

#### failure: Attempting to grant access for an already-granted agency-client pair is rejected [b7654f43]
Given an agency already has an access grant (of any kind) on a client account
When any party attempts to create a second grant for the same agency-client pair
Then the operation is rejected with a conflict error
And only the original grant remains

### Any agency team member (regardless of their role on the agency account) can navigate into a client account through the agency-client access grant — navigation is not restricted to the agency owner

#### happy: Agency team member navigates into a client account [8ba9717c]
Given a user is a member (non-owner) of an agency account
And the agency has an access grant on a client account
When the agency member views the client dashboard and clicks to enter that client account
Then the current context switches to the client account
And the member can perform actions permitted by the agency's access level on that client

### The client dashboard lists every managed client account; each row displays the client account name and the agency's access level only — no status column is shown.

#### happy: Dashboard shows all client accounts with name and access level [7c0ca162]
Given an agency has two originated client accounts and one invited client account
When the agency owner views the client dashboard
Then all three client accounts are listed
And each row shows the client account name and the agency's access level
And the originated accounts are distinguishable from the invited one (e.g., via access level label)
And no status column or status indicator is present anywhere in the table

#### failure: Dashboard variant with a status column is rejected [424c66e4]
Given a regression ships a dashboard table that includes a "Status" column alongside name and access level
When QA inspects the rendered table
Then the status column is flagged as a violation of this rule
And the column is removed before merge — only client account name and access level are rendered per row

## Questions
- [resolved] What values does "status" take on a client account for the dashboard display? (e.g. active, inactive, trial) — the dashboard rule references status but the set of possible values isn't defined yet.
- [resolved] When an agency creates a client account (originator flow), does any user automatically become a member of that client account, or does the agency need to separately invite someone to it?
- [resolved] Can non-owner agency team members (admin or member role on the agency account) also navigate into client accounts from the dashboard, or is that restricted to the agency owner?
- [resolved] Is the invited access flow (client granting an agency access) in scope for this MVP, or is it a future feature? For the first customer, all client accounts will be agency-originated, so this may not be needed yet.
