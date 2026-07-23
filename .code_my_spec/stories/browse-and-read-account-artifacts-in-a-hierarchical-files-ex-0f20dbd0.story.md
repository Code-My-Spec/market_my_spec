# Browse and read account artifacts in a hierarchical files explorer

As a user reviewing my agent's work, I want a single files interface with a hierarchical tree of every artifact my current account has access to on the left and the selected file rendered as styled markdown on the right, so I can navigate and read all my agent's outputs in one place without a separate viewer or guessing at paths.

## Meta
- id: 0f20dbd0-af8c-45d1-816f-4535aeae3810
- number: 684
- status: in_progress
- priority: 2
- component: MarketMySpecWeb.FilesLive.Browser
- personas: agency-owner

## Rules

### The files explorer only shows artifacts belonging to the user's currently-selected account; artifacts from other accounts are never visible.

#### happy: Tree only contains the active account's artifacts [1dc2c1f3]
Given Alex is signed in and has Account A active
And Account A has artifacts at "specs/auth.md" and "notes/pricing.md"
And Account B (which Alex also belongs to) has an artifact at "specs/billing.md"
When Alex opens the files explorer
Then the tree shows "specs/auth.md" and "notes/pricing.md"
And the tree does not show "specs/billing.md"

#### failure: Direct access to a foreign-account artifact is denied [9478ef51]
Given Alex is signed in with Account A active
And a known artifact path "specs/billing.md" exists only in Account B
When Alex attempts to load that artifact in the right pane (e.g. by URL or stale link)
Then the artifact is not rendered
And Alex sees a not-found or unauthorized state, not the file contents

### The left pane presents artifacts as a hierarchical tree that mirrors the storage path structure, so users can navigate without guessing at paths.

#### happy: Nested paths render as a navigable tree [29c11b19]
Given the active account has artifacts at "specs/auth/login.md", "specs/auth/signup.md", and "notes/launch.md"
When Alex opens the files explorer
Then the tree shows a "specs" node containing an "auth" node with "login.md" and "signup.md"
And the tree shows a "notes" node containing "launch.md"
And expanding or collapsing a folder node hides or reveals its children

### Selecting a markdown file in the tree renders its contents as styled markdown in the right pane.

#### happy: Selecting a markdown file renders it styled on the right [fb7a0e2d]
Given the active account has an artifact at "specs/auth.md" containing a heading, a list, and a fenced code block
When Alex clicks "auth.md" in the tree
Then the right pane renders the file's contents as styled markdown
And the heading appears as a heading, the list as a list, and the code block in a monospace block
And the raw markdown source is not visible

### Switching the active account reloads the tree to show the new account's artifacts and clears any selection that no longer applies.

#### happy: Switching accounts re-scopes the tree and clears stale selection [e1859df2]
Given Alex has Account A active and "specs/auth.md" selected and rendered on the right
When Alex switches the active account to Account B
Then the tree reloads to show Account B's artifacts
And "specs/auth.md" is no longer selected
And the right pane no longer shows the previously rendered file

### When the active account has no artifacts, the explorer shows an empty-state placeholder in both panes instead of an error or a blank screen.

#### happy: Empty account shows an empty-state placeholder [17beb457]
Given Alex's active account has zero artifacts
When Alex opens the files explorer
Then the left pane shows an empty-state message indicating no files exist yet
And the right pane shows a placeholder prompting Alex to select a file (which there are none of)
And no error is shown

### Rendering non-markdown files is out of scope. The explorer is not required to defensively handle non-md selection — let it crash and rely on the supervisor to recover.

#### happy: Selecting a non-markdown file is undefined behavior [06ecd813]
Given the active account contains a non-markdown artifact (e.g. "image.png" or "data.json")
When Alex selects that artifact in the tree
Then the explorer is not required to render it gracefully
And no defensive handling, error UI, or fallback rendering is in scope for this story
And a process crash is acceptable; the supervisor restarts the LiveView

## Questions
- [resolved] Non-markdown files: tree-scope answer was 'all files in the account's files backend' but rendering non-md is 'out of scope for this story'. Resolve before implementation: do non-md files appear in the tree but are non-selectable, are they filtered out entirely, or is rendering them deferred to a follow-up story?
