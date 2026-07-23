# Public Landing Page

As a visitor to the Market My Spec landing page, I want a clear page that explains what Market My Spec does, who it is for (AI-native solo founders), and that it requires bringing my own Claude account, so I can decide whether to sign up without confusion about cost or fit.

## Meta
- id: 62b02f76-b39e-4e0e-9cda-2044d6612425
- number: 633
- status: in_progress
- priority: 1
- component: MarketMySpec.Skills.Overview
- personas: founder

## Rules

### The hero displays a concrete marketing-strategy artifact (real markdown excerpt or screenshot) above the fold, alongside the headline and primary CTA — not abstract value-prop copy alone. (Per 03_personas.md "What closes it: a real strategy doc visible on the page.")

#### happy: Visitor sees a real strategy artifact in the hero [5a861549]
Given a visitor loads the landing page at "/"
When the hero renders within the first viewport
Then they see the headline, a visible markdown excerpt of an actual strategy artifact (e.g., a snippet from a positioning.md output), and the primary install-command CTA — all without scrolling

#### failure: Hero with no artifact fails the proof-on-page bar [7b812162]
Given a hero variant ships with only headline + abstract subhead + CTA
When QA inspects the first viewport on a 1440x900 desktop and a 390x844 mobile screen
Then no concrete strategy artifact is visible
And the variant fails the "real doc visible on the page" closing-criterion from 03_personas.md

### The primary above-the-fold CTA is the copyable plugin install command in monospace, not a "Sign up" button. Visitors can copy and run it without creating an account first — sign-up happens implicitly during OAuth on first /marketing-strategy invocation.

#### happy: Visitor copies install command without an auth gate [8c324949]
Given a visitor loads the landing page at "/"
When they see the install command in the hero rendered in a monospace block with a copy affordance
And they click the copy button
Then the install command lands in their clipboard
And no sign-up modal, email-capture form, or auth gate is presented at any point

#### failure: Sign-up gate in front of install command is rejected [34bb298b]
Given a hero variant ships a "Sign up to get the install command" gate
When QA reviews the hero against the messaging guide ("Don't gate value behind signup" — 06_messaging.md)
Then the variant is rejected
And the primary CTA is reverted to a fully-visible, copy-on-click install command with no auth gate

### BYO-Claude appears below the hero as a positive benefit ("Bring your own Claude. We don't markup your tokens."), not as a gate-warning that crowds the hero. The page does not loudly deflect non-fit visitors — the install command itself is the qualifier.

#### happy: BYO-Claude lives below hero as a benefit line [c46770a9]
Given the landing page renders for a visitor
When they scroll past the hero into the next strip
Then they see a single line "Bring your own Claude. We don't markup your tokens." framed as a benefit
And the hero itself contains no eligibility warnings, no "requires Claude subscription" callouts, and no copy that pushes the artifact below the fold

#### failure: Hero with BYO-Claude warning copy is rejected [fdba22cb]
Given a hero variant includes "Requires a Claude subscription — see eligibility" warning copy in the first viewport
When QA inspects the hero against the brand test ("empower, don't gatekeep" — 00_brand.md) and the messaging guide
Then the variant is rejected
And the BYO-Claude content is moved below the hero and reframed as the positive "your tokens, your bill" benefit

### The page is product-forward, positioned for AI-native solo founders ("Marketing for founders, in Claude Code"). It contains no AI-bro hype phrases ("10x your reach", "AI-powered marketing automation", "go viral"), no enterprise-feature checklist (SSO, audit logs, RBAC), no "Trusted by [logos]" bar, no course/info-product framing, and no surface-mismatch CMS phrases ("Elixir-first", "specification-driven").

#### happy: Page passes the messaging-guide phrase audit [d6d1d1ec]
Given the landing page is rendered end-to-end
When QA grep-audits the rendered HTML against the banned-phrase list (06_messaging.md "phrases NOT to use") and the brand-anti-patterns (00_brand.md "where it does NOT show up")
Then no banned phrases appear: "10x", "go viral", "AI-powered marketing", "next-gen", "revolutionize", "Lights out software factory", "Elixir-first", "specification-driven"
And no enterprise-feature section, no "Trusted by" logos bar, and no course-style "learn marketing in 30 days" framing is present
And the headline contains the canonical positioning "Marketing for founders, in Claude Code"

#### failure: Draft with banned phrase or enterprise framing is rejected [8e3fae3c]
Given a draft of the page includes "10x your marketing" in the subheadline OR a "Trusted by [logos]" bar OR a "specification-driven" mention
When QA runs the messaging-guide phrase audit
Then the draft is rejected against 06_messaging.md
And the offending element is removed before merge

### An agency-shaped visitor can opt into a discovery-call lane via a tertiary "Run an agency? Talk to John" link, kept visually subordinate to the install path so it never competes with the solo install funnel.

#### happy: Agency visitor finds the Talk-to-John lane below install [b62c377b]
Given a visitor scrolls past the install CTA
When they reach the secondary content strip
Then they see a small "Run an agency? Talk to John" link rendered as text or a subtle inline button
And the install command remains the visually dominant CTA on the page (larger type, monospace, copy affordance)
And the agency link's visual weight does not match or exceed the install command

#### failure: Equal-weight agency CTA next to install is rejected [c77d0776]
Given a draft renders "Talk to John" as a primary button next to the install command, both same size and same color
When QA inspects the CTA hierarchy
Then the draft is rejected — solo install must remain the dominant path so it doesn't pull P0 traffic into the slow discovery-call lane
And the agency CTA is restyled as a tertiary inline link, visually subordinate
