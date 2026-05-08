# Qa Result

## Status

pass

## Scenarios

### 1. Hierarchical tree renders (criterion 5986)

Pass. Signed in as `qa@marketmyspec.test`, navigated to `http://localhost:4008/files`. The page renders a tree with the expected structure:

- `[data-test='file-tree']` container present
- Top-level folder nodes `[data-test='tree-folder-marketing']`, `[data-test='tree-folder-specs']`, `[data-test='tree-folder-data']` all visible
- Nested folder `[data-test='tree-folder-marketing/research']` visible under `marketing`
- Leaf files `[data-test='tree-file-specs/auth/login.md']` and `[data-test='tree-file-data/blob.json']` visible
- Folders use `<details open>` / `<summary>` so the user can expand/collapse

Evidence: `.code_my_spec/qa/684/screenshots/01-tree-default.png`.

### 2. Tree is gated by active account (criterion 5984)

Pass. Same session, primary account active. The tree contains the primary account's artifacts and does NOT contain `[data-test='tree-file-notes/secondary-only.md']` (which lives in the secondary account `QA Secondary`). `vibium browser_is_visible` returned `false` for that selector. Evidence is rolled into `01-tree-default.png` — the absence is what's load-bearing.

### 3. Markdown rendering (criterion 5987)

Pass. Clicked `[data-test='tree-file-specs/auth/login.md']` from the tree. URL became `/files/specs%2Fauth%2Flogin.md`. The right pane rendered `<article class="prose prose-invert max-w-none mt-6">` containing:

- `<h1>Login spec</h1>` (text-extracted via `vibium browser_get_text article.prose h1` → "Login spec")
- A `<code class="language-elixir">` block with the Elixir snippet from the seed
- No raw `\`\`\`elixir` fence visible

Evidence: `.code_my_spec/qa/684/screenshots/02-markdown-render.png`.

### 4. Direct foreign-account access denied (criterion 5985)

Pass. Still signed in as the primary qa user, navigated directly to `http://localhost:4008/files/specs/private-billing.md` (a path that exists only in the foreign `QA Workspace` account). The page rendered with:

- `[data-test='artifact-error']` visible
- Body text "File not available."
- The foreign-artifact body strings ("Private billing", "shhh") were NOT in the DOM

Evidence: `.code_my_spec/qa/684/screenshots/03-foreign-access-denied.png`.

### 5. Account switching re-scopes the tree (criterion 5988)

Pass. Navigated to `/accounts/picker`, observed both accounts listed with `[data-test='account-picker-item-qa-secondary']` and `[data-test='account-picker-item-qa-agency-test']`; the primary was marked Current. Clicked the secondary item. The picker handler invoked `Accounts.set_active_account_context/2` and redirected to `/files`. URL after click: `http://localhost:4008/files`. The new tree shows:

- `[data-test='tree-file-notes/secondary-only.md']` visible (the secondary's only artifact)
- `[data-test='tree-folder-marketing']` NO longer visible
- `[data-test='tree-file-specs/auth/login.md']` NO longer visible
- The previous selection (`/files/specs/auth/login.md`) is no longer present in the URL

Evidence: `.code_my_spec/qa/684/screenshots/04-after-switch.png`. After-the-fact, switched back to the primary via the picker for the next test.

### 6. Empty-state placeholder (criterion 5989)

Pass. Signed in via the magic-link as `qa-empty@marketmyspec.test` (single account, no artifacts). Navigated to `/files`. The page rendered:

- `[data-test='empty-state']` visible
- `[data-test='file-tree']` NOT visible
- Copy: "No artifacts yet" + the run-a-skill instruction

Evidence: `.code_my_spec/qa/684/screenshots/06-empty-state.png`.

### 7. Non-markdown selection is undefined / let-it-crash (criterion 5990)

Pass. Signed back in as the primary qa user, navigated directly to `http://localhost:4008/files/data/blob.json`. The LiveView raised `RuntimeError: Non-markdown artifacts are out of scope: "data/blob.json"` from `MarketMySpecWeb.FilesLive.Show.assign_body/3:50`, which is exactly the contract:

- The page does not render the JSON body
- No defensive fallback (no `<pre>`, no markdown article)
- The supervisor restarts the LV — Phoenix's debugger error page is what the dev session sees

Evidence: `.code_my_spec/qa/684/screenshots/05-non-md-crash.png`.

## Evidence

- `.code_my_spec/qa/684/screenshots/01-tree-default.png` — primary account tree, top-level + nested folder nodes visible, expected leaves present
- `.code_my_spec/qa/684/screenshots/02-markdown-render.png` — `specs/auth/login.md` rendered as styled HTML with heading + elixir code block
- `.code_my_spec/qa/684/screenshots/03-foreign-access-denied.png` — direct URL to a foreign-account artifact, "File not available." in `data-test='artifact-error'`
- `.code_my_spec/qa/684/screenshots/04-after-switch.png` — after switching to QA Secondary, only `notes/secondary-only.md` is in the tree
- `.code_my_spec/qa/684/screenshots/05-non-md-crash.png` — non-markdown artifact triggers the documented RuntimeError, body is never rendered
- `.code_my_spec/qa/684/screenshots/06-empty-state.png` — empty user, `data-test='empty-state'` placeholder, no tree

## Issues

### Default-active account is non-deterministic without an explicit pin

#### Severity
LOW

#### Scope
QA

#### Description

`Scope.for_user/1` falls back to `hd(MembersRepository.list_user_accounts(user.id))` when `user.active_account_id` is nil. The repo's ordering is not pinned in the QA seed flow, so for a user with multiple memberships the "default" account is whatever the repo returns first — in this run, the secondary account came back first even though the primary was created earlier. I added an explicit `Repo.update!(active_account_id: primary)` to `priv/repo/qa_seeds_684.exs` to make the test scenario deterministic. If a future story adds account creation in a way that flips this ordering, the seed would need refreshing rather than the spex/test contract changing — leaving as a QA-side note rather than an APP bug.

### Magic-link single-account user has no remember-me option

#### Severity
INFO

#### Scope
APP

#### Description

When `qa-empty@marketmyspec.test` (one account, fresh confirmation) hit the magic-link confirmation page, only one button rendered ("Log in") rather than the two-button "Keep me logged in / Log me in only this time" pair the multi-account user sees. Not a regression from this story, just a UX note for future Auth review — both flows ended up authenticated, so no functional impact for QA.
