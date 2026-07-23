# Save and run named keyword searches across venues

As a solo founder, I want to save named keyword-list searches scoped to a chosen subset of my venues, so my agent can re-run a recurring engagement scan by name instead of re-typing the keywords and venue filter every time.

## Meta
- id: 6fbdc850-3754-4f84-b160-426af5127d92
- number: 710
- status: in_progress
- component: MarketMySpecWeb.SearchLive
- personas: agent, founder

## Rules

### A Search must have at least one venue selector at create or update time. A selector is either a specific Venue id or an "all enabled venues of source X" wildcard (supported only on sources where it's meaningful, e.g. ElixirForum). Empty selection is rejected.

#### happy: Sam creates a search scoped to two specific Reddit subreddits [61d62d2b]
Given Sam's account has Reddit venues r/elixir and r/programming
When Sam creates a Search named "elixir hiring" with those two venue ids
Then the Search is persisted with both venue selectors and the create succeeds

#### happy: Sam creates a search scoped to "all ElixirForum" [aa35def6]
Given Sam's account has at least one enabled ElixirForum venue
When Sam creates a Search named "elixir testing" with selector {source: :elixirforum, all: true}
Then the Search is persisted with the wildcard selector and the create succeeds
And running the search fans out across every currently-enabled ElixirForum venue on Sam's account

#### failure: Creating a search with empty venue selection is rejected [a9ed16da]
Given Sam's account exists
When Sam attempts to create a Search named "needs venues" with an empty venue selector list
Then the create is rejected with a validation error on the venue selectors field
And no Search row is persisted

### Search names are unique within an account but mutable. A second create or a rename collision in the same account fails; two different accounts can have searches with the same name.

#### happy: Two accounts can each have a search named "elixir testing" [fab7fa21]
Given account A and account B each have at least one venue
When Sam (on account A) creates a Search named "elixir testing"
And a member of account B creates a Search named "elixir testing"
Then both creates succeed and the searches are scoped to their respective accounts

#### failure: Renaming a search to a name already taken on the same account fails [44965af3]
Given Sam's account has Searches "elixir testing" and "credo nitpicks"
When Sam tries to rename "credo nitpicks" to "elixir testing"
Then the update is rejected with a unique-constraint error on name
And the search keeps its original name

### Search keywords are stored as a single Google-style query string supporting quoted phrases, AND/OR operators, and negation. The orchestrator parses operators at run time and fans out per the syntax.

#### happy: run_search interprets OR alternates and quoted phrases [d13c01b8]
Given Sam has a Search "elixir testing" with query string `"elixir testing" OR credo`
When the agent calls run_search on that Search
Then the candidate list includes results matching the phrase "elixir testing" and results matching the term "credo"
And results matching neither are excluded

### Any account member and the connected MCP agent can list, create, update, delete, and run saved searches in their own account. Cross-account access (read, write, run) returns :not_found and never leaks data.

#### happy: A member-role user can create and run a saved search [6540e5cd]
Given Maya is a member (non-owner) of Sam's account
And the account has at least one venue
When Maya creates a Search via the admin UI and clicks "Run now"
Then the create succeeds and the candidate list is rendered on the page

#### failure: Cross-account run_search call returns not_found [9055eea3]
Given account A owns Search S
And Dave is signed in on account B (not a member of account A) with an MCP bearer scoped to B
When Dave's agent calls run_search with S's UUID
Then the response is an error tagged :not_found
And no candidate data from account A is returned

### run_search reuses the existing Engagements.Search.search/3 orchestrator and returns the same %{candidates, failures} JSON shape as the ad-hoc search_engagements tool. No run history is persisted — saved searches are recipes only.

#### happy: run_search delegates to the shared orchestrator and persists nothing [c3514c2d]
Given Sam has a saved Search with a query and two venues
When the agent calls run_search with the Search's UUID
Then the response carries `candidates` and `failures` with the same shape as ad-hoc search_engagements
And no run-history row is inserted in any table
And subsequent list_searches calls show no run-history fields on the Search

### Saved searches are accessible via both MCP tools (create_search, list_searches, run_search, update_search, delete_search) and a LiveView admin at /accounts/:id/searches. The existing ad-hoc search_engagements tool keeps working — saved searches are additive, not a replacement for keyword-on-the-fly search.

#### happy: Sam manages searches in the admin UI while the agent uses the same surface via MCP [3700a69b]
Given Sam is signed in on his account
When Sam visits /accounts/:id/searches
Then the page lists his saved searches with name, query, venue count, and a "Run now" action per row
And the agent (on the same account, over MCP) can call list_searches and see the same set
And the agent can still call the existing ad-hoc search_engagements tool with a one-off keyword and venue filter without touching saved searches
