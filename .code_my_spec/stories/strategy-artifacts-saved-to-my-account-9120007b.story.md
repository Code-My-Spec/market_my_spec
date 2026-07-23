# Strategy Artifacts Saved To My Account

As a user completing the marketing strategy interview, I want my strategy artifacts (current state, jobs/segments, personas, beachhead, positioning, messaging, channels, 90-day plan) persisted to my MMS account workspace as the agent walks me through each step — so I can read them in the MMS web UI, share them with an agency collaborator on the same account, refine them in a future agent session, and never depend on the local filesystem state of the machine I happened to run the interview on. The agent persists each step's artifact through the MMS file API exposed over MCP (story 683); the canonical filename table is preserved across runs so re-running the interview overwrites artifacts in place rather than creating numbered duplicates.

## Meta
- id: 9120007b-d128-451f-aeba-099b3cef4e83
- number: 676
- status: in_progress
- priority: 1
- component: MarketMySpecWeb.McpController
- personas: agent, founder

## Rules

### Static skill audit — every step file directs the agent to persist its artifact via the write_file MCP tool at the canonical path. For every N in 1..8, `priv/skills/marketing-strategy/steps/NN_<slug>.md` contains a literal directive instructing the agent to call the `write_file` MCP tool with `path` set to `marketing/NN_<destination>.md` and `content` set to the step's artifact body. The destination filenames match the canonical SKILL.md mapping (e.g., `03_persona_research.md` → `marketing/03_personas.md`; all others mirror the source basename). Test by reading each step file and grepping for the `write_file` tool reference and the canonical destination path.

#### happy: Each step file passes the write_file directive audit [2c9f4c3b]
Given the shipped skill at priv/skills/marketing-strategy/steps/
When QA runs a static audit over the 8 step files
Then for each file the audit asserts the body contains the literal canonical destination path (e.g., "marketing/05_positioning.md" in 05_positioning.md)
And the body contains a write_file MCP tool reference (matches "write_file" in instruction context)
And all 8 files pass

#### failure: Step file lacking write_file directive is rejected [ecd19be0]
Given a regression edit removes the "call write_file with path: marketing/05_positioning.md" directive from priv/skills/marketing-strategy/steps/05_positioning.md
When the static audit runs
Then it reports the file as failing — destination path is absent OR write_file tool reference is absent
And the test suite blocks the merge until the directive is restored

### Canonical filename table preserved across runs — destination filenames are exactly: `marketing/01_current_state.md`, `marketing/02_jobs_and_segments.md`, `marketing/03_personas.md`, `marketing/04_beachhead.md`, `marketing/05_positioning.md`, `marketing/06_messaging.md`, `marketing/07_channels.md`, `marketing/08_plan.md`. Stable across releases so re-runs overwrite in place and an agency collaborator viewing the artifacts in the MMS web UI sees the same paths over time. The agent passes only the canonical relative path; the server prepends `accounts/{account_id}/` internally.

#### happy: Destination filenames match the canonical table [08837e69]
Given the canonical 8-entry destination list
When the audit extracts the "marketing/..." paths referenced in each step file
Then the union of extracted paths exactly matches the canonical set: 01_current_state.md, 02_jobs_and_segments.md, 03_personas.md, 04_beachhead.md, 05_positioning.md, 06_messaging.md, 07_channels.md, 08_plan.md
And no extra or missing destinations are present
And every path is a relative path (no leading slash, no accounts/ prefix)

#### failure: Drifted filename (e.g., timestamped variant) is rejected [a892ef2b]
Given a regression edit changes the destination in step 05_positioning.md from "marketing/05_positioning.md" to "marketing/05_positioning_v2.md" or to an absolute path "/marketing/05_positioning.md"
When the canonical-filename audit runs
Then the destination set no longer matches the canonical list
And the test reports the offending step file and the divergent filename
And the merge is blocked until the canonical name is restored

### Skill content uses hosted-artifact language — no local-filesystem references. A regex sweep over every .md file under `priv/skills/marketing-strategy/` finds zero occurrences of phrases that imply local-filesystem persistence: `Write tool`, `./marketing/`, `your local marketing`, `in your working directory`, `commit to git locally`. The shipped skill instructs the agent to persist artifacts via the MMS file API (write_file), not via the agent's own local Write tool against the user's filesystem.

#### happy: Skill content sweep finds no local-filesystem language [2cd58ac5]
Given the shipped skill at priv/skills/marketing-strategy/
When QA runs a regex sweep over every .md file in the directory tree
Then no file contains any of the banned phrases: "Write tool", "./marketing/", "your local marketing", "in your working directory", "commit to git locally"
And the audit logs which files were scanned and confirms the sweep returned zero hits

#### failure: Prompt edit introducing local-filesystem language is caught by the sweep [e8c5612c]
Given a prompt edit adds the line "Use your Write tool to save ./marketing/05_positioning.md" to priv/skills/marketing-strategy/steps/05_positioning.md
When the banned-phrase audit runs
Then it reports the file path, line number, and matched phrase
And the test fails and blocks the merge
And the offending line is removed (or rephrased to delegate the write to the write_file MCP tool with a relative canonical path) before the audit passes

### After the agent completes a step over MCP and the skill instruction is followed, the artifact is retrievable from the user's account workspace via the file API. When the agent calls `write_file` with `path: "marketing/05_positioning.md"` and the step 5 artifact body, a subsequent `read_file` on the same path under the same bearer token returns that body byte-for-byte, and `list_files` with `prefix: "marketing/"` includes that key. The artifact crosses the conversation boundary — visible to a future agent session under the same account, and visible to an agency collaborator viewing the FilesLive surface.

#### happy: User completes step 5 and finds positioning.md in their account workspace [5c59bd94]
Given the agent has walked the user through steps 1-5 of the marketing strategy interview over MCP
And the user is authenticated under a single account
When the agent finishes step 5 (positioning) and calls write_file with path "marketing/05_positioning.md" and the artifact body
Then a subsequent read_file with path "marketing/05_positioning.md" under the same bearer token returns that exact body
And list_files with prefix "marketing/" includes "marketing/05_positioning.md"
And the write happened at the conclusion of step 5 — not deferred or batched with later steps

### Re-running the interview overwrites the canonical filename in place — no numbered duplicates. After step 5 has been persisted once, a re-run that produces a new step 5 artifact follows the read-before-overwrite path: the agent calls `read_file` on `marketing/05_positioning.md`, then `write_file` on the same path with the new body. The object count under `marketing/` does not grow across re-runs. No `marketing/05_positioning_v2.md`, no `marketing/05_positioning_2.md`, no timestamped variants ever appear in `list_files`.

#### happy: Re-running the interview overwrites stable filenames, not numbered duplicates [43881bb6]
Given marketing/05_positioning.md already exists in the user's account workspace from a prior interview run
When the user re-runs the marketing-strategy skill and completes step 5 again
Then the agent calls read_file on marketing/05_positioning.md (satisfying the read-before-overwrite gate)
And the agent calls write_file on marketing/05_positioning.md with the new body, overwriting the previous version
And no marketing/05_positioning_v2.md, marketing/05_positioning_2.md, or timestamped variant is created
And list_files under prefix "marketing/" still shows exactly one positioning.md key
And the file contains the updated positioning content from the current run
