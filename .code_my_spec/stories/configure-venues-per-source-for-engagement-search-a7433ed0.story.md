# Configure venues per source for engagement search

As a solo founder, I want to tell the system which subreddits, forum categories, and tags to search — both via the LLM through MCP tools and via a manual admin UI — so search results match my ICP without me touching code or restarting the server.

Each Source defines what a "venue" means for it: Reddit venue = subreddit name; ElixirForum venue = category + optional tag filter. Venues are persisted, source-typed, and carry a weight used for ranking. The LLM can manage them via MCP tools (so it can adjust the venue mix as patterns emerge), and I can manage them via a LiveView admin page when I want to do bulk edits or just eyeball the list.

This is the pre-requisite story for the engagement-finder loop. Story 705 (search) reads its venue list from here.

## Meta
- id: a7433ed0-36d2-4436-959e-b87f48114b42
- number: 708
- status: in_progress
- component: MarketMySpecWeb.VenueLive
- personas: agent, founder

## Rules

### A venue is fully described by its source, an identifier valid for that source, a weight used for ranking, and an enabled flag.

#### happy: A new Reddit venue persists with all fields [0ca02226]
Given no venues exist yet
When I add a venue with source "reddit", identifier "ClaudeAI", weight 1.5, and enabled true
Then the venue is persisted with source "reddit", identifier "ClaudeAI", weight 1.5, and enabled true
And it appears in the venue list filtered by source "reddit"

#### happy: An ElixirForum venue stores category and optional tag filter [b1e94730]
Given no venues exist yet
When I add a venue with source "elixirforum", identifier {category: "your-libraries", tag: "ai"}, weight 1.0, and enabled true
Then the venue is persisted with the category "your-libraries" and tag filter "ai"
And the same venue without a tag filter is treated as a separate venue

#### happy: Weight and enabled flag take sensible defaults [d3ac0ad4]
Given no venues exist yet
When I add a venue with only source and identifier specified
Then the venue is persisted with enabled true and weight 1.0

### Adding a venue validates its identifier against the source's rules before it lands.

#### happy: A valid Reddit subreddit name is accepted [50dddeb7]
Given no venues exist for source "reddit"
When I add a venue with source "reddit" and identifier "ChatGPTCoding"
Then the venue is accepted and persisted

#### failure: An invalid Reddit subreddit name is rejected with an error [5612b4fe]
Given no venues exist for source "reddit"
When I add a venue with source "reddit" and identifier "not a valid sub name"
Then the venue is not persisted
And I receive a validation error naming the invalid identifier format

#### failure: An ElixirForum venue with an unknown category is rejected [e7f37318]
Given no venues exist for source "elixirforum"
When I add a venue with source "elixirforum" and category "definitely-not-a-real-category"
Then the venue is not persisted
And I receive a validation error indicating the category is not recognized

### The MCP Agent can create, list, update, and remove venues via dedicated MCP tools.

#### happy: The agent creates a venue via add_venue MCP tool [626ab4e5]
Given the agent is connected over MCP with a valid bearer token
When the agent calls `add_venue` with source "reddit" and identifier "elixir"
Then the response contains the created venue id, source, identifier, weight, and enabled flag
And the venue appears in subsequent `list_venues` calls

#### happy: The agent lists venues, optionally filtered by source [3eb06892]
Given two Reddit venues and one ElixirForum venue exist
When the agent calls `list_venues` with no filter
Then it receives all three venues
When the agent calls `list_venues` with source "reddit"
Then it receives only the two Reddit venues

#### happy: The agent updates a venue's weight and enabled flag [5cd75b00]
Given a Reddit venue exists with weight 1.0 and enabled true
When the agent calls `update_venue` with weight 2.0 and enabled false
Then the venue's weight becomes 2.0 and enabled becomes false
And subsequent `list_venues` calls reflect the new values

#### happy: The agent removes a venue via remove_venue MCP tool [35e4ec59]
Given a Reddit venue exists
When the agent calls `remove_venue` with the venue id
Then the venue is deleted
And it no longer appears in `list_venues` results

### Solo Shipper Sam can view, add, edit, enable/disable, and remove venues from a LiveView admin page.

#### happy: Sam views the venue list in the admin LiveView [15f236fb]
Given Sam is signed in as the account owner
And two venues exist (one Reddit, one ElixirForum)
When Sam visits the venues admin page
Then both venues are listed with source, identifier, weight, and enabled state visible

#### happy: Sam adds a new venue from the admin UI [4480b1e9]
Given Sam is on the venues admin page
When Sam fills in source "reddit", identifier "vibecoding", weight 1.0 and submits the new-venue form
Then the venue appears in the list without a page reload
And the venue is persisted in the database

#### happy: Sam toggles a venue's enabled flag from the list row [fae595e5]
Given a venue exists with enabled true
When Sam clicks the toggle on the venue's row
Then the venue's enabled flag flips to false in the database
And the row reflects the new state without a page reload

#### happy: Sam removes a venue from the admin UI [86386d99]
Given a venue exists
When Sam clicks the remove action on the venue's row and confirms
Then the venue is deleted from the database
And the row disappears from the list without a page reload

### Search reads only enabled venues per source, and toggling a venue's enabled flag takes effect on the next search without redeployment.

#### happy: Disabling a venue removes it from the next search [55a8c238]
Given two Reddit venues exist, both enabled
When the agent runs a search across all Reddit venues
Then both venues are queried
When one venue is disabled and the agent runs the same search
Then only the still-enabled venue is queried

#### happy: Re-enabling a venue restores it to the search target set [dc2da69c]
Given a Reddit venue exists with enabled false
When the venue is re-enabled and the agent runs a search across Reddit venues
Then that venue is queried alongside any other enabled Reddit venues

### Venues are scoped to an account — all CRUD operations (MCP and admin UI) only see and affect venues belonging to the active account.

#### happy: Each account sees only its own venues [523ea309]
Given account A has one Reddit venue
And account B has one Reddit venue
When the agent for account A calls `list_venues`
Then it receives only account A's venue
When Sam (signed into account A) opens the admin venues page
Then she sees only account A's venue

#### failure: Cross-account venue access is rejected [0906638e]
Given account A has a Reddit venue with id V
And the agent is connected as account B
When the agent calls `update_venue` or `remove_venue` with id V
Then the operation is rejected with a not-found error
And venue V remains unchanged in account A

## Questions
- [resolved] Are venues account-scoped (per tenant) or system-wide? MMS supports multi-tenant accounts elsewhere — does the engagement-finder venue list belong to the account, or is it a single global list for John's instance?
- [resolved] What does "weight" mean in practice — a multiplier on per-result ranking, or a hint to allocate query budget proportionally across venues, or both? Default 1.0 is assumed but the actual semantics aren't pinned down.
