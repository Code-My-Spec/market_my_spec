# Agent File Tools Over MCP

As the user's MCP-connected agent (Claude Code, Cursor, Aider, Cline, or any MCP-capable coding/writing assistant), I want Read/Write/Edit-style file tools over MCP — read_file, write_file, edit_file, delete_file, list_files — that operate on artifacts in the user's currently-active account workspace. The tool shape mirrors Claude Code's local file tools so I can use them with no extra prompt scaffolding: write_file creates or overwrites (with read-before-overwrite gating), edit_file does exact-string replacement (with read-before-edit gating), delete_file removes a file (with read-before-delete gating), and list_files returns keys under an optional prefix. The bearer token resolves to one account; relative paths I pass resolve under that account's prefix server-side, so I never see — or have to manage — the account scoping. This is the file-API contract that story 676 (Strategy Artifacts Saved To My Account) builds on top of, and it must work for any MCP-capable agent the user happens to be running.

## Meta
- id: fdc9f655-9f1f-4ed8-aafd-d965c496ab31
- number: 683
- status: in_progress
- priority: 1
- component: MarketMySpec.Files.Memory
- personas: agent

## Rules

### tools/list exposes the five file primitives with Claude-Code-shaped input schemas; the surface stays tight. The MCP `tools/list` response includes exactly five file tools — `read_file` (`{path}`), `write_file` (`{path, content}`), `edit_file` (`{path, old_string, new_string, replace_all?}`), `delete_file` (`{path}`), `list_files` (`{prefix?}`) — alongside the project's skill primitives (`invoke_skill`, `read_skill_file`) and any auth helpers. No adjacent admin, debug, or telemetry tools live on the same surface.

#### happy: tools/list response includes the five file tools with the right shapes [18527004]
Given an authenticated MCP client issues a tools/list JSON-RPC request to /mcp
When the response is parsed
Then the tool names returned include exactly: read_file, write_file, edit_file, delete_file, list_files (plus invoke_skill, read_skill_file, and auth helpers)
And read_file's input_schema declares required parameter "path"
And write_file's input_schema declares required parameters "path" and "content"
And edit_file's input_schema declares required "path", "old_string", "new_string" and optional "replace_all"
And delete_file's input_schema declares required parameter "path"
And list_files's input_schema declares optional parameter "prefix"

#### failure: Adjacent admin or debug tool fails the surface audit [9d8c646c]
Given a regression adds an MCP tool "admin_purge_account" or "debug_dump_keys" to the surface
When the tool-surface audit runs over tools/list
Then the audit detects the non-allowlisted tool name and reports it as a violation
And the test fails and blocks the merge
And the implementation is reverted — the file surface stays tight to the five primitives plus skill + auth helpers

### All paths resolve under `accounts/{account_id}/` via the bearer-token-resolved account; the agent passes relative paths only. Every file tool resolves the caller-supplied `path` under `accounts/{account_id}/<path>` server-side, where `{account_id}` is derived from the bearer token's resolved account. The agent never sees, sends, or constructs the `accounts/` prefix. Path traversal segments (`..`), absolute paths (leading `/`), and any path that resolves outside the account prefix are rejected with a structured error. There is no addressable way for one bearer token to read, write, edit, delete, or list keys belonging to a different account.

#### happy: Relative path resolves under the caller's account prefix server-side [9f07a74c]
Given an authenticated MCP client whose bearer token resolves to account_id 42
When the agent calls write_file with path "marketing/05_positioning.md" and content "..."
Then the object is stored at the backing key "accounts/42/marketing/05_positioning.md"
And the agent's path argument never contained the "accounts/" prefix
And read_file with path "marketing/05_positioning.md" under the same bearer token returns the stored content

#### failure: Path traversal is rejected [1596c9b6]
Given an authenticated MCP client whose bearer token resolves to account_id 42
When the agent calls read_file with path "../43/marketing/05_positioning.md"
Then the call returns a structured invalid_path error
And no read is performed against the backing store
And the same outcome holds for write_file, edit_file, delete_file, and list_files when given a path containing ".." segments

#### failure: Absolute path is rejected [5514a5ca]
Given an authenticated MCP client
When the agent calls write_file with path "/etc/passwd" and content "..."
Then the call returns a structured invalid_path error
And no write is performed against the backing store
And the same outcome holds for any path with a leading "/"

#### failure: Cross-account access is impossible by construction [acc59ea1]
Given an MCP client A whose bearer token resolves to account_id 42 has written marketing/05_positioning.md
And an MCP client B whose bearer token resolves to account_id 99 connects to /mcp
When client B calls read_file with path "marketing/05_positioning.md"
Then the response is a structured not_found error against B's own account scope
And no key from account_id 42 is returned
And list_files under client B returns only B's own keys, never A's
And no syntactic path argument B can construct (relative, absolute, or traversal) reaches A's keys

### read_file returns the file body for an existing key under the caller's account prefix and returns a structured not-found error for missing keys. The body is returned byte-for-byte (no transformation, no truncation by default). Calling `read_file` adds the path to the per-MCP-session "read set" used by the read-before-modify gates on `write_file`, `edit_file`, and `delete_file`. A miss returns a structured `not_found` error with the requested relative path echoed back; nothing about the underlying account-prefixed key is leaked.

#### happy: read_file returns body for an existing key [2b8a6ce3]
Given marketing/05_positioning.md exists under the caller's account prefix with body "Positioning v1\n"
When the agent calls read_file with path "marketing/05_positioning.md"
Then the response contains the byte-exact body "Positioning v1\n"
And the path "marketing/05_positioning.md" is added to the session's read set
And subsequent edit_file or write_file (overwrite) on the same path within the same session is permitted

#### failure: read_file on a missing path returns structured not_found [31b47bfa]
Given no object exists at marketing/never_written.md under the caller's account prefix
When the agent calls read_file with path "marketing/never_written.md"
Then the response is a structured not_found error
And the error echoes the requested relative path "marketing/never_written.md"
And the error does not leak the underlying account-prefixed key
And the path is NOT added to the session's read set

### write_file is create-or-overwrite with read-before-overwrite gating. If the target path does not yet exist under the caller's account prefix, `write_file` creates the object and succeeds. If the target path exists, `write_file` succeeds only when the same path was returned by `read_file` earlier in the same MCP session. Without a prior read in the session, an attempt to overwrite an existing path returns a structured `read_required` error and the existing object is left untouched. Mirrors Claude Code's local Write semantics exactly.

#### happy: write_file on a fresh path creates the object [b83e3ff8]
Given no object exists at marketing/05_positioning.md under the caller's account prefix
When the agent calls write_file with path "marketing/05_positioning.md" and content "Positioning v1\n"
Then the call returns success
And a subsequent read_file on the same path returns "Positioning v1\n"
And no prior read_file was required because the path did not exist

#### happy: write_file on an existing path with prior read overwrites in place [2eb9d760]
Given marketing/05_positioning.md exists with body "Positioning v1\n"
And the agent has called read_file on "marketing/05_positioning.md" earlier in the same MCP session
When the agent calls write_file with path "marketing/05_positioning.md" and content "Positioning v2\n"
Then the call returns success
And a subsequent read_file on the same path returns "Positioning v2\n"
And no second copy is created — the path count under the prefix is unchanged

#### failure: write_file on existing path without prior read is rejected [10c8fafd]
Given marketing/05_positioning.md exists with body "Positioning v1\n"
And the agent has not called read_file on that path in the current MCP session
When the agent calls write_file with path "marketing/05_positioning.md" and content "Positioning v2\n"
Then the call returns a structured read_required error
And the existing body is unchanged — read_file (after the failure) still returns "Positioning v1\n"

### edit_file performs exact-string replacement of `old_string` with `new_string` in the named path; requires a prior `read_file` of that path in the same MCP session; errors on non-uniqueness unless `replace_all` is true; errors with not-found if the path does not exist. The match is byte-exact, no normalization. When `old_string` occurs more than once and `replace_all` is unset (or false), the call returns a structured `non_unique_match` error and the file is left untouched. When `replace_all` is true, every occurrence is replaced. Without a prior `read_file` of the path in the session, the call returns `read_required` and does nothing.

#### happy: edit_file replaces a unique old_string in a previously-read file [08dd2b61]
Given marketing/05_positioning.md exists with body "We help teams ship faster.\nDetails follow.\n"
And the agent has called read_file on that path in the current MCP session
When the agent calls edit_file with path "marketing/05_positioning.md", old_string "ship faster", new_string "ship safer"
Then the call returns success
And a subsequent read_file on the same path returns "We help teams ship safer.\nDetails follow.\n"
And the file body changed only at the matched location, byte-exact

#### happy: edit_file with replace_all replaces every occurrence [e06d6dcd]
Given marketing/05_positioning.md exists with body "ICP: founders. ICP refinement: technical founders.\n"
And the agent has called read_file on that path in the current MCP session
When the agent calls edit_file with path "marketing/05_positioning.md", old_string "ICP", new_string "Ideal Customer Profile", replace_all true
Then the call returns success
And a subsequent read_file returns "Ideal Customer Profile: founders. Ideal Customer Profile refinement: technical founders.\n"
And every occurrence of "ICP" in the file was replaced

#### failure: edit_file without prior read is rejected [4fa65f9b]
Given marketing/05_positioning.md exists with a known body
And the agent has not called read_file on that path in the current MCP session
When the agent calls edit_file with path "marketing/05_positioning.md", old_string "X", new_string "Y"
Then the call returns a structured read_required error
And the file body is unchanged

#### failure: edit_file with non-unique old_string and no replace_all is rejected [16a01c2d]
Given marketing/05_positioning.md exists with body "ICP: founders. ICP refinement: technical founders.\n"
And the agent has called read_file on that path in the current MCP session
When the agent calls edit_file with path "marketing/05_positioning.md", old_string "ICP", new_string "Ideal Customer Profile" (replace_all unset)
Then the call returns a structured non_unique_match error
And the file body is unchanged
And the error reports the count of matches found (>= 2) so the agent can resubmit with replace_all if intended

#### failure: edit_file on missing path returns not_found [7c5cc366]
Given no object exists at marketing/never_written.md under the caller's account prefix
When the agent calls edit_file with path "marketing/never_written.md", old_string "X", new_string "Y"
Then the call returns a structured not_found error
And no object is created — write_file is the only path to create

### delete_file removes the object at the given path under the caller's account prefix; requires a prior `read_file` of that path in the same MCP session. Without a prior read in the session, the call returns a structured `read_required` error and the object is left intact. After a successful delete, a subsequent `read_file` on the same path returns `not_found`, and the path no longer appears in `list_files`. Delete is idempotent only after the first successful invocation — re-deleting an already-deleted path returns `not_found`, not silent success.

#### happy: delete_file after read removes the object [6f6e00f4]
Given marketing/05_positioning.md exists with body "Positioning v1\n"
And the agent has called read_file on that path in the current MCP session
When the agent calls delete_file with path "marketing/05_positioning.md"
Then the call returns success
And a subsequent read_file on the same path returns a structured not_found error
And list_files under prefix "marketing/" no longer includes "marketing/05_positioning.md"

#### failure: delete_file without prior read is rejected [f1ae5e81]
Given marketing/05_positioning.md exists
And the agent has not called read_file on that path in the current MCP session
When the agent calls delete_file with path "marketing/05_positioning.md"
Then the call returns a structured read_required error
And the object remains intact — a subsequent read_file returns the original body

### list_files returns relative keys under the caller's account prefix; the account-prefix portion is stripped before return; an optional `prefix` filter narrows the result to keys whose relative form starts with that prefix. Returned keys are always relative (no leading `accounts/` segment, no leading slash). With no `prefix` argument, every key under the account is returned. With a `prefix` argument like `"marketing/"`, only matching relative keys appear. Cross-account leakage is structurally impossible — the listing is always scoped server-side by the bearer token's account.

#### happy: list_files returns relative keys under the caller's account prefix [23a0d1b4]
Given the caller's account prefix contains keys: marketing/05_positioning.md, marketing/06_messaging.md, README.md
When the agent calls list_files with no prefix argument
Then the response is a list containing exactly: "marketing/05_positioning.md", "marketing/06_messaging.md", "README.md"
And no returned key contains "accounts/" as a prefix
And no returned key has a leading slash

#### happy: list_files with prefix filter narrows the result [22a144be]
Given the caller's account prefix contains keys: marketing/05_positioning.md, marketing/06_messaging.md, README.md
When the agent calls list_files with prefix "marketing/"
Then the response contains exactly: "marketing/05_positioning.md", "marketing/06_messaging.md"
And "README.md" is excluded — it does not match the prefix
And the prefix portion is preserved in returned keys (the agent uses these paths verbatim with the other tools)
