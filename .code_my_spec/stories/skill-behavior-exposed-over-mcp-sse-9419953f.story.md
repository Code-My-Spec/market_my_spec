# Skill Behavior Exposed Over MCP (SSE)

As a connected agent (the user's Claude Code), I want the Market My Spec MCP to expose the marketing-strategy skill's orientation and step prompts as MCP resources/tools (over SSE transport), so I can drive the 8-step interview flow following progressive disclosure — load orientation first, then load each step prompt only when reached.

## Meta
- id: 9419953f-332a-4312-b484-a03343ad5854
- number: 675
- status: in_progress
- priority: 1
- component: MarketMySpec.Skills.MarketingStrategy
- personas: founder

## Rules

### The MCP transport is SSE-based per the Streamable HTTP spec — POST with JSON-RPC for client-to-server, long-lived text/event-stream responses for server-to-client. Each connection carries a bearer token; resource fetches return the body within the SSE stream tied to the originating mcp-session-id.

#### happy: MCP session initializes over SSE and serves resources [eebd29e4]
Given an MCP client with a valid bearer token
When it POSTs an initialize JSON-RPC request to /mcp with Authorization header
Then the response carries Content-Type: text/event-stream and an mcp-session-id header
And the SSE stream is opened and ready to deliver subsequent results
When the client POSTs resources/read for "mcp://marketing-strategy/orientation" using the same mcp-session-id
Then the server responds with HTTP 202 Accepted on the POST
And the orientation body is delivered as an SSE event on the original initialize stream
And the agent receives the body without polling or out-of-band callbacks

#### failure: Plain non-SSE client cannot read resource bodies [d1d0526d]
Given a client uses one-shot curl (no SSE handling) and POSTs resources/read to /mcp
When MMS responds with HTTP 202 Accepted (per Anubis Streamable HTTP behavior)
Then the body of the response does not contain the resource content
And the client cannot retrieve the body without an open SSE stream tied to mcp-session-id
And the QA plan documents this — see plan.md System Issues for "Anubis MCP requires SSE-aware client, plain curl gives 202"
And full e2e validation uses an MCP-aware client (Claude Code) or mix test against the server modules

### The MCP server exposes a tool `invoke_skill(skill_name)` which returns the body of the named skill's SKILL.md. This is the entry point — the agent never needs to know file paths, only the skill name. The returned SKILL.md is responsible for telling the agent what other files to read next via `read_skill_file`. Tool name is namespaced to avoid collision with Claude Code's built-in tools (no plain "skill" or "invoke").

#### happy: Agent invokes marketing-strategy and receives SKILL.md [f0318597]
Given an authenticated MCP client with a valid bearer token
When the agent calls the `invoke_skill` tool with arguments `{"skill_name": "marketing-strategy"}`
Then the response body contains the full text of `priv/skills/marketing-strategy/SKILL.md` (frontmatter + body)
And the body opens with `---\nname: marketing-strategy\n` and includes the literal string `steps/01_current_state.md` so the agent can call `read_skill_file` for the first step
And the agent's context contains only this orientation document — no step bodies are loaded yet

#### failure: Invoking an unknown skill returns a clear MCP error [b324feeb]
Given an authenticated MCP client
When the agent calls `invoke_skill` with `{"skill_name": "nonexistent-skill"}`
Then MMS returns a JSON-RPC error with a clear message ("skill not found") naming the requested skill
And the response does not leak the list of available skill directories or filesystem paths
And no SKILL.md body is returned

### The MCP server exposes a tool `read_skill_file(skill_name, path)` which returns the body of a file inside the named skill's directory by relative path. The agent uses this to load individual step files on demand (e.g., `steps/01_current_state.md`), implementing the progressive-disclosure pattern that SKILL.md documents — orientation first, then one step's content at a time. Tool name avoids collision with Claude Code's built-in `Read` (which takes only a path).

#### happy: Agent reads step 3 file on demand and only step 3 lands in context [b92f607c]
Given the agent has already invoked the marketing-strategy skill and completed steps 1-2
When it calls `read_skill_file` with `{"skill_name": "marketing-strategy", "path": "steps/03_persona_research.md"}`
Then the response body equals the contents of `priv/skills/marketing-strategy/steps/03_persona_research.md`
And the body does not contain the orientation, step 1, step 2, step 4, or any other step's content
And the agent's context now holds the orientation summary plus only step 3

#### failure: Reading a non-existent step file returns a not-found error [b4fddcac]
Given the agent calls `read_skill_file` with `{"skill_name": "marketing-strategy", "path": "steps/09_extra.md"}`
When MMS resolves the path under the skill directory and the file does not exist
Then MMS returns a JSON-RPC error indicating the file was not found
And no fallback content (orientation, an adjacent step, or a directory listing) is silently returned
And the agent surfaces the error to the user instead of fabricating content

### Skills are backed by files on disk under `priv/skills/<skill_name>/`. Each skill has a `SKILL.md` at the root (with YAML frontmatter naming the skill, description, user-invocable flag, optional argument-hint) plus a subtree of supporting content. The marketing-strategy skill mirrors the canonical structure published in the user-facing plugin (`plugins/plugins/market-my-spec/skills/marketing-strategy/`) — `SKILL.md` + `steps/01_current_state.md` through `steps/08_plan.md`. Source-of-truth is the file content; MMS does not synthesize prompts at runtime.

#### happy: Marketing-strategy skill mirrors the canonical plugin file tree [2d908a32]
Given the marketing-strategy skill is shipped under `priv/skills/marketing-strategy/`
When QA inspects the skill directory
Then the directory contains exactly: `SKILL.md` and a `steps/` subdirectory
And `steps/` contains exactly: `01_current_state.md`, `02_jobs_and_segments.md`, `03_persona_research.md`, `04_beachhead.md`, `05_positioning.md`, `06_messaging.md`, `07_channels.md`, `08_plan.md`
And `SKILL.md` contains valid YAML frontmatter with `name: marketing-strategy`, a `description`, `user-invocable: true`, and an `argument-hint` field
And byte-for-byte content matches the published `plugins/plugins/market-my-spec/skills/marketing-strategy/` reference at the time of release (a sync test compares them)

#### failure: Skill missing SKILL.md or with synthesized-at-runtime content is rejected [fda1c123]
Given an alternative implementation that synthesizes the SKILL.md body at runtime from a database row or hardcoded module string
When QA inspects the response of `invoke_skill` against the file content of `priv/skills/marketing-strategy/SKILL.md`
Then any drift between the response and the on-disk file is a bug — the file is the source of truth
And a skill missing its `SKILL.md` (only step files present) fails the structure audit and is rejected
And the implementation is reverted to read from disk (or compiled-in resources from the same files at build time)

### `read_skill_file` enforces path safety: only normalized paths that resolve under `priv/skills/<skill_name>/` are served. Absolute paths, paths containing `..`, symlinks pointing outside the skill, and unknown-skill names are rejected with an MCP error before any filesystem read. This prevents an agent (or a hostile MCP client) from using the tool as a generic file-read primitive.

#### happy: Path-traversal attempts are rejected before any filesystem read [f58d0aec]
Given an MCP client calls `read_skill_file` with each of the following malicious arguments:
  - {"skill_name": "marketing-strategy", "path": "../../etc/passwd"}
  - {"skill_name": "marketing-strategy", "path": "/etc/passwd"}
  - {"skill_name": "marketing-strategy", "path": "steps/../../mix.exs"}
  - {"skill_name": "../../../../etc", "path": "passwd"}
When MMS validates each request
Then each is rejected with a JSON-RPC error before any filesystem call is made
And no file content from outside `priv/skills/marketing-strategy/` is returned
And the request is logged at warn level so abuse can be observed

#### failure: Implementation that allows arbitrary reads is rejected by audit [bc039a2a]
Given a regression ships `read_skill_file` that calls `File.read!(Path.join(root, path))` without normalizing or rejecting `..` segments
When the path-safety test suite runs (the four malicious payloads above)
Then at least one payload returns content from outside the skill root
And the test suite catches the regression before merge
And the implementation is reverted to use `Path.safe_relative/1` (or equivalent) and to verify the resolved path is still under `priv/skills/<skill_name>/` before reading
