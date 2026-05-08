# QA Brief: Story 684 — Files explorer

## Tool

MCP browser tools (Vibium). The feature is a LiveView at `/files` and `/files/*key`. There are no JSON / API surfaces for this story.

## Auth

Use the magic-link URLs printed by the seed script (single-use tokens).

1. Run the seed (see Seeds below) and copy the relevant magic-link URL from the output.
2. `browser_navigate <magic-link URL>` — Vibium follows the redirect and lands the tester on the post-login page with a session cookie set.
3. From there, navigate to `http://localhost:4008/files` (or other paths under the populated user) without re-authenticating.

If a magic-link comes back consumed, re-run the seed to mint a fresh one.

## Seeds

```
PORT=4008 mix run priv/repo/qa_seeds.exs
PORT=4008 mix run priv/repo/qa_seeds_684.exs
```

The 684 seed is idempotent and depends on the base seeds. It outputs three magic-link URLs:

- **`qa@marketmyspec.test`** — primary user. Has TWO accounts (`QA Agency Test` is the default active account, populated with 6 artifacts incl. nested folders + one non-markdown file; `QA Secondary` has one distinctive artifact `notes/secondary-only.md`).
- **`qa-empty@marketmyspec.test`** — has one account, zero artifacts. Use to verify empty-state placeholder.
- **Foreign account** (`QA Workspace`, owned by `qa-foreign@marketmyspec.test`) — has a single artifact `specs/private-billing.md`. The tester does NOT sign in as this user; its account exists so cross-account scoping rules have something to refute against.

The seed prints all three magic-link URLs; copy the ones you need.

## What To Test

Work through the seven acceptance criteria. Capture a screenshot at every key state and reference it from the result. Save screenshots to `.code_my_spec/qa/684/screenshots/` (note: Vibium writes them to `~/Pictures/Vibium/` regardless of path; copy them over after each shot per the QA plan's known issue).

### 1. Hierarchical tree renders (criterion 5986)

- Sign in as `qa@marketmyspec.test` (primary user).
- Navigate to `http://localhost:4008/files`.
- Expect: a tree container with `data-test="file-tree"`, top-level folder nodes `marketing` and `specs` (and `data`) each with `data-test="tree-folder-marketing"` / `data-test="tree-folder-specs"` / `data-test="tree-folder-data"`.
- Expect: nested folder `data-test="tree-folder-marketing/research"` exists under `marketing` with leaves `competitors.md` and `personas.md`.
- Expect: folder nodes use `<details>`/`<summary>` so they expand/collapse when clicked.
- Screenshot: `tree-default.png`.

### 2. Tree is gated by active account (criterion 5984)

- While signed in as `qa@marketmyspec.test` (primary, `QA Agency Test` active):
- Confirm the tree contains `marketing/01_current_state.md`, `specs/auth/login.md`, etc.
- Confirm the tree does NOT contain `secondary-only.md` (which lives in `QA Secondary`) and does NOT contain `private-billing.md` (which lives in the foreign account `QA Workspace`).
- Screenshot: same `tree-default.png` is fine if scope is visible; otherwise add `tree-active-account-only.png`.

### 3. Markdown rendering (criterion 5987)

- From the tree, click `specs/auth/login.md` (or use `browser_click` with `data-test="tree-file-specs/auth/login.md"`).
- Expect: navigate to `/files/specs/auth/login.md`, right-pane shows rendered HTML — `<h1>Login spec</h1>`, code in a `<code class="language-elixir">` block, no raw `\`\`\`elixir` fence visible.
- Screenshot: `markdown-render.png`.

### 4. Direct foreign-account access denied (criterion 5985)

- While still signed in as `qa@marketmyspec.test`, navigate directly to `http://localhost:4008/files/specs/private-billing.md` (the path that exists only under the foreign account).
- Expect: the file body ("Private billing", "shhh") is NOT visible. An element with `data-test="artifact-error"` shows a "File not available" message.
- Screenshot: `foreign-access-denied.png`.

### 5. Empty-state placeholder (criterion 5989)

- Sign in (in the same Vibium session, or open a fresh login flow) as `qa-empty@marketmyspec.test`.
- Navigate to `/files`.
- Expect: a placeholder element with `data-test="empty-state"` and copy "No artifacts yet". No tree container is rendered. No error indicator.
- Screenshot: `empty-state.png`.

### 6. Account switching re-scopes the tree (criterion 5988)

- Back as `qa@marketmyspec.test`. Confirm the tree shows the primary account's artifacts and does NOT show `secondary-only.md`.
- Navigate to `http://localhost:4008/accounts/picker`.
- Click the option that targets `QA Secondary` (selector: `[phx-value-account-id="<QA Secondary's account id from seed output>"]`).
- After the redirect, navigate (or be redirected) back to `/files`.
- Expect: tree now shows `notes/secondary-only.md` and does NOT show `marketing/01_current_state.md` or any other primary-account artifact.
- Screenshot: `after-switch.png`.

### 7. Non-markdown is undefined (criterion 5990)

- Back on the primary account workspace at `/files`.
- Navigate directly to `http://localhost:4008/files/data/blob.json` (or click the `data-test="tree-file-data/blob.json"` leaf if the tree exposes it).
- Expect: a server-side crash (LV process exits, supervisor restarts) OR the page renders without the JSON body and without invoking the markdown pipeline. The body string `"non-markdown — should not render"` MUST NOT appear in the rendered HTML.
- Screenshot: `non-md-crash.png` (capture whatever the user sees — error page, blank page, or a flash). If Vibium's mount fails outright, capture the network response code.

## Result Path

`.code_my_spec/qa/684/result.md`

## Setup Notes

- Dev server port is **4008** (per the project's CLAUDE.md and recent QA briefs — the QA plan still says 4007, that's stale). Start the server with `PORT=4008 mix phx.server`.
- Files backend in dev is `MarketMySpec.Files.Disk` (root: `tmp/files/`). The seed's `Files.put` writes are visible at `tmp/files/accounts/<account_id>/...` — useful for verification outside the browser.
- If a magic-link token has been consumed by an earlier sign-in, re-run `mix run priv/repo/qa_seeds_684.exs` to mint a fresh one.
- The `data/blob.json` file is the only deliberate non-markdown artifact. Per criterion 5990, the implementation raises rather than rendering it — this is intentional, not a bug. Capture whatever the user sees and treat any *graceful* fallback rendering of the JSON body as a failure.
- The account picker's `account-selected` event used to merely navigate to `/accounts/{id}` without changing the active account. Story 684 wires it to call `Accounts.set_active_account_context/2` and redirect to `/files`. If you observe the picker landing on an account manage page instead of `/files`, the dev server hasn't reloaded — restart it.
