# Agency Subdomain Assignment and Host Routing

As an agency owner, I want to claim a unique subdomain on marketmyspec.com (e.g. `acme.marketmyspec.com`) so my clients access the platform under my agency's name and the platform's host router resolves the subdomain into my agency's scoped context. The subdomain is the agency's identity on the platform; the agency's branding (logo, colors) is rendered on top of it in a separate story.

## Meta
- id: f3badb7b-901f-40d3-a1a3-e36c7fba008e
- number: 695
- status: in_progress
- component: MarketMySpecWeb.Plugs.AgencyHost
- personas: agency-owner

## Rules

### An agency subdomain must be globally unique across all agency accounts.

#### happy: Owner claims an unused subdomain [0742047a]
Given an agency-typed account "Acme Marketing" with no subdomain set
And no other agency has claimed the subdomain "acme"
When an owner of "Acme Marketing" sets the subdomain to "acme"
Then the subdomain "acme" is recorded on the agency
And future requests to "acme.marketmyspec.com" resolve into the Acme Marketing context

#### failure: Owner attempts to claim a subdomain already taken [ebafbb1a]
Given the agency "Beta Inc" has already claimed the subdomain "acme"
And an agency-typed account "Acme Marketing" has no subdomain set
When an owner of "Acme Marketing" attempts to set the subdomain to "acme"
Then the update is rejected with an error indicating the subdomain is already taken
And "Acme Marketing" still has no subdomain set

### An agency subdomain must be lowercase alphanumeric plus hyphens, 3-50 characters, must start with a letter, and must not be a reserved name (admin, api, www, help, support, docs, blog).

#### happy: Owner sets a well-formed subdomain [d7fa40e3]
Given an agency-typed account "Acme Marketing" with no subdomain set
When an owner sets the subdomain to "acme-marketing"
Then the update succeeds
And the subdomain "acme-marketing" is recorded on the agency

#### failure: Owner submits a malformed subdomain [c8466586]
Given an agency-typed account "Acme Marketing"
When an owner attempts to set the subdomain to "Acme!"
Then the update is rejected with a format-error message
And the subdomain is unchanged

#### failure: Owner attempts to claim a reserved subdomain [416148a1]
Given an agency-typed account "Acme Marketing"
When an owner attempts to set the subdomain to "admin"
Then the update is rejected with a reserved-name error
And the subdomain is unchanged

### Only agency-typed accounts can claim a subdomain; individual-typed accounts cannot.

#### failure: Individual account attempts to claim a subdomain [1ed35e65]
Given an individual-typed account "Sam's Solo"
When the owner attempts to set a subdomain
Then the update is rejected because subdomains require an agency-typed account
And no subdomain is recorded

### An agency member with :manage_account rights (owner or admin) can set or change the agency's subdomain.

#### happy: Admin changes the subdomain [afa0d17c]
Given an agency "Acme Marketing" with subdomain "acme"
And Alice is an admin member of "Acme Marketing"
When Alice sets the subdomain to "acme-co"
Then the update succeeds
And the subdomain on "Acme Marketing" is "acme-co"

#### failure: Member-role user attempts to change the subdomain [0baa5733]
Given an agency "Acme Marketing" with subdomain "acme"
And Bob is a member-role user of "Acme Marketing"
When Bob attempts to set the subdomain to "acme-co"
Then the update is rejected as unauthorized
And the subdomain on "Acme Marketing" is still "acme"

### Requests to a known agency subdomain resolve into that agency's scoped LiveView context.

#### happy: Visitor hits an active agency subdomain [de128269]
Given the agency "Acme Marketing" has subdomain "acme"
When a visitor navigates to "acme.marketmyspec.com"
Then the request is routed to the LiveView surface
And the current scope is set to the "Acme Marketing" agency context

### API endpoints (OAuth, MCP, .well-known) are served only on the apex domain, not on agency subdomains.

#### happy: API call hits the apex domain [18a853d8]
Given a registered MCP client with a valid bearer token
When the client posts to "marketmyspec.com/mcp"
Then the request is handled by the MCP controller
And the response follows the MCP protocol

#### failure: API call hits an agency subdomain [7764a55c]
Given the agency "Acme Marketing" has subdomain "acme"
When a client posts to "acme.marketmyspec.com/mcp"
Then the request is not served as an API call
And the client receives a 404

### The apex domain serves the default platform surface with no agency scope, regardless of any agency's configuration.

#### happy: Visitor lands on the apex domain [9dff6fc3]
Given any number of agencies with subdomains in the system
When a visitor navigates to "marketmyspec.com"
Then they see the default Market My Spec platform surface
And no agency scope is set on the request

### An unrecognized subdomain — any slug not currently claimed by an agency — redirects to the apex. The system does not maintain history of previously-claimed subdomains; "stale" and "never-claimed" are treated identically.

#### happy: Visitor hits an unrecognized subdomain [7ef5896a]
Given no agency currently claims the subdomain "ghost"
When a visitor navigates to "ghost.marketmyspec.com"
Then they are redirected to "marketmyspec.com"

#### happy: Visitor hits a former subdomain after the agency renamed [515f6e0e]
Given the agency "Acme Marketing" previously had subdomain "acme" and changed it to "acme-co"
And no other agency currently claims "acme"
When a visitor navigates to "acme.marketmyspec.com"
Then they are redirected to "marketmyspec.com"
And there is no special handling that distinguishes the former-subdomain case from a never-claimed case

## Questions
- [resolved] How is stale-subdomain history tracked so the host plug can distinguish a previously-claimed subdomain (return 404) from a never-claimed one (redirect to apex)? Options: a `previous_subdomains` table, a `released_at` column on agency, or denormalize history into the accounts table.
