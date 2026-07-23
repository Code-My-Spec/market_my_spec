# Agency Branding Configuration

As an agency owner, I want to configure my agency's branding — logo URL, primary color, and secondary color — so that when my clients access Market My Spec through my agency's subdomain they see my agency's brand rather than the platform's default branding. Subdomain assignment and host routing is handled by a separate story; this story assumes the agency already has a working subdomain. If branding is unconfigured, clients see the Market My Spec default theme.

## Meta
- id: 69679da5-71a5-4ec4-acba-c51688e1d5a9
- number: 691
- status: in_progress
- component: MarketMySpecWeb.AgencyLive.Settings
- personas: agency-owner

## Rules

### An agency member with :manage_account rights (owner or admin) can configure the agency's logo URL, primary color, and secondary color.

#### happy: Owner saves all three branding fields [e4acf292]
Given an agency "Acme Marketing" with no branding configured
And Alice is an owner of "Acme Marketing"
When Alice submits logo URL "https://acme.example/logo.svg", primary "#22c55e", secondary "#1d4ed8"
Then the branding is saved on the agency

#### failure: Member-role user attempts to save branding [3108880c]
Given an agency "Acme Marketing" with no branding configured
And Bob is a member-role user of "Acme Marketing"
When Bob submits a branding update
Then the update is rejected as unauthorized
And no branding is saved

### The logo URL must be a valid HTTPS URL (format-validated, not fetched at save time).

#### happy: Owner submits an HTTPS logo URL [08923331]
Given an agency "Acme Marketing"
When an owner submits logo URL "https://acme.example/logo.svg"
Then the URL is accepted

#### failure: Owner submits an HTTP-only logo URL [76cc4db5]
Given an agency "Acme Marketing"
When an owner submits logo URL "http://acme.example/logo.svg"
Then the update is rejected with a "must be HTTPS" error

#### failure: Owner submits a malformed logo URL [d952f255]
Given an agency "Acme Marketing"
When an owner submits logo URL "not-a-url"
Then the update is rejected with a URL format error

### Primary and secondary colors must be valid 6-character hex codes in the form #rrggbb.

#### happy: Owner submits valid hex colors [5177dfb2]
Given an agency "Acme Marketing"
When an owner submits primary "#22c55e" and secondary "#1d4ed8"
Then both color values are accepted and stored

#### failure: Owner submits a malformed color [6a92aaf5]
Given an agency "Acme Marketing"
When an owner submits primary "blue" or "#abc" or "#12345"
Then the update is rejected with a hex-format error indicating the expected #rrggbb form

### When a request resolves into an agency context (i.e., on the agency's subdomain), the agency's configured logo and colors are applied via daisyUI's --color-primary and --color-secondary tokens.

#### happy: Visitor on a configured agency subdomain sees branding [4daca5ae]
Given the agency "Acme Marketing" has subdomain "acme" with logo URL "https://acme.example/logo.svg", primary "#22c55e", secondary "#1d4ed8"
When a visitor navigates to "acme.marketmyspec.com"
Then the rendered page applies "#22c55e" to the daisyUI --color-primary token
And applies "#1d4ed8" to --color-secondary
And displays the agency's logo in the top-left navbar slot

### When an agency has not configured branding, requests on that agency's subdomain render with the Market My Spec default theme.

#### happy: Visitor on an unconfigured agency subdomain sees default theme [4f12ad93]
Given the agency "Acme Marketing" has subdomain "acme" but no branding configured
When a visitor navigates to "acme.marketmyspec.com"
Then the page renders with the Market My Spec default theme tokens
And the navbar shows the Market My Spec default logo

### Agency branding never bleeds onto the apex domain or onto another agency's subdomain.

#### happy: Visitor on apex sees default theme regardless of agency configuration [41205e9f]
Given the agency "Acme Marketing" has fully configured branding
When a visitor navigates to "marketmyspec.com"
Then the page renders with the Market My Spec default theme
And the agency's logo and colors are not applied

#### happy: Visitor on a different agency's subdomain sees that agency's branding only [91b89d40]
Given the agency "Acme Marketing" has subdomain "acme" with primary "#22c55e"
And the agency "Beta Inc" has subdomain "beta" with primary "#dc2626"
When a visitor navigates to "beta.marketmyspec.com"
Then the page renders with primary "#dc2626"
And does not apply Acme Marketing's branding

### The agency logo renders in a fixed top-left navbar slot. If the logo URL fails to load in the browser, the agency's name renders as a text fallback in the same slot.

#### failure: Logo URL fails to load in the browser [5726a488]
Given the agency "Acme Marketing" has logo URL "https://acme.example/missing.png"
And the resource at that URL returns 404 in the browser
When a visitor navigates to "acme.marketmyspec.com"
Then the top-left navbar slot displays the text "Acme Marketing"
And the broken image is not rendered
