# MCP Agent

> "Give me Read/Write/Edit on the user's account workspace. Make it shaped exactly like the file tools I already have — I'll do the rest."

Proto-persona for the AI coding/marketing agent that connects to Market My Spec over MCP and acts on the user's behalf. Not the human user — the *agent* the human is driving. Mark as proto and validate against three real connection sessions (Claude Code, Cursor, one open-source agent like Aider or Cline) before any claim becomes load-bearing.

## Role

The user's locally-running agent — Claude Code, Cursor, Aider, Cline, OpenCode, Codex CLI, Windsurf, or another MCP-capable coding/writing assistant. Connects to MMS over MCP (SSE transport), authenticates via OAuth, and executes the marketing-strategy skill on the user's behalf. Reads skill content, drives the interview, produces artifacts, and persists those artifacts back into the user's account workspace via MMS file tools. [E1, E2]

The agent is not a single product — it's a fleet. Claude Code dominates current usage (~46% loved-most rating, #1 tool by adoption growth in 2026), but the user might equally be on Cursor (~1M devs, ~360k paid, 64% of Fortune 500), Aider (strongest open-source baseline since 2023), Cline (autonomous open-source agent with native MCP), or one of a dozen others. 70% of developers run 2–4 AI tools simultaneously; 15% run 5 or more. The persona is "any of them," not "one of them." [E2, E3]

## Goals

**Do the user's work without losing context.** The agent is mid-conversation with the user. Every round-trip to a server tool that fails, returns garbage, or needs a different shape than the agent already knows costs the user one of two things — context tokens or trust. The agent's goal on every MMS call is "succeed first try, return the smallest correct response." [E1, E5]

**Use tools whose shape I already know.** Anthropic's Read/Write/Edit and the read-before-edit invariant are the de facto reference design — they ship in Claude Code natively and are mirrored or wrapped by every major competitor. An MCP server whose file API matches that shape needs zero new prompt scaffolding for the agent to use correctly. A divergent shape (custom verbs, content-as-blob, opaque IDs instead of paths) burns prompt budget on workarounds. [E1, E4]

**Stay inside my scope.** The agent is bounded to one user's active account at a time — no cross-tenant access, no path traversal, no privilege escalation. The bearer token resolves to one account; relative paths the agent passes resolve under that account's prefix server-side. The agent doesn't want to think about scoping; the server handles it. [E2, E5]

**Persist work the user can find later.** Every artifact the agent produces (positioning.md, ICP, channels, plan) needs to survive the conversation. The user expects to find them in MMS's web UI later, share them with an agency collaborator, or pull them back into a future agent session for refinement. The agent's write paths must be stable, predictable, and visible. [E1, E4]

## Pain Points

**Tool-shape mismatch eats context.** A divergent file API forces the model to read the tool description carefully on every call, retry on small protocol errors, and write longer arguments. With Claude Code's 200K context, every wasted ~10K is a real cost; with Aider's 126K, more so. A truncation regression in Claude Code's own Read tool produced ~25K-token responses vs. ~100-byte error throws — that's the order of magnitude at stake when tool surfaces drift. [E1, E5]

**No read-before-write means correlated corruption.** Claude Code's own design enforces "Read before Edit/Write-overwrite" because models without that gate happily overwrite files based on stale memory. An agent connecting to a server that allows blind overwrites will produce wrong artifacts confidently — and the wrongness compounds across the eight-step interview. [E1]

**Account scope ambiguity.** Without server-side scoping, the agent has to remember which account the user is currently in and prepend a prefix to every path. That's an extra fact to track per call, and it leaks security boundaries into prompt logic where they don't belong. The agent wants the server to handle this and reject anything out-of-scope. [E2]

**MCP resource bloat.** With ~10,000 active public MCP servers and 7.8x server-registry growth in a year, agents are increasingly running multi-server connections. A server that spams `tools/list` with adjacent helpers (debug, admin, telemetry) crowds the agent's tool selection space. The MMS surface must stay tight — the file primitives plus the skill primitives, nothing else. [E2]

**Hosted-state opacity.** When artifacts live server-side instead of on the local filesystem, the agent loses the ability to "just `ls`" to find them. Without a `list_files` tool, the agent's only recourse is to remember every path it has written this session — fragile across long interviews and impossible across sessions. [E1, E4]

## Context

**MCP is the industry-default connector.** It crossed from "Anthropic-led standard" to "industry-default standard" between July 2025 and February 2026. Every frontier lab now ships client support — Claude (native), ChatGPT (April 2025), Google Gemini API + Vertex AI Agent Builder (March 2026), Cursor, Windsurf, Zed, JetBrains AI Assistant, Vercel AI SDK, OpenAI Agents SDK. Average integration time fell from ~18 hours of custom function-calling to ~4.2 hours over MCP; 56% of orgs report it materially cut new-tool integration cost. By March 2026, ~10,000 active public servers and ~97M monthly SDK downloads (Python + TS combined). Building MMS as an MCP server reaches every major agent without per-client work. [E2]

**The Claude Code file API is the reference.** Anthropic's three-tool design — `Read` (read-only, paginated, dedup-aware), `Write` (create or full overwrite, requires prior Read of any existing file), `Edit` (exact string replacement, sends only the diff, requires prior Read) — is the most battle-tested file API any agent has, ships natively in Claude Code, and is what the underlying models have been most extensively trained against. Mirroring it gets the most agent-coverage per design dollar. [E1]

**The agent fleet is heterogeneous.** Claude Code leads adoption but does not own the market. The 14-tool benchmark roundup ranks Claude Code, Cursor, Codex CLI, OpenCode, Cline, Aider, Pi, Windsurf, Continue, Goose, Roo Code, Augment, Amp, and others as live competitors. A common stack pattern is "Claude Code or Codex for agentic work + Copilot or Cursor for inline completion + one open-source tool (Aider/Cline/OpenCode) for flexibility." MMS's file API has to work for any of them. [E3]

**Agentic workflows are mainstream.** 55% of survey respondents regularly use AI agents; staff+ engineers lead at 63.5%. Multi-file editing, repository-scale refactors, and autonomous task execution have become the default mode of work, not an edge case. An MCP server feeding into these flows is touched many times per session, not once. [E3, E4]

**Skill-driven flows benefit from artifact persistence.** When the agent is walking the user through an eight-step interview, each step's output needs to be re-readable in later steps for cross-references and consistency checks. Server-side persistence (vs. local filesystem) lets the agent retrieve step 3's persona artifact while writing step 5's positioning — without depending on the user's local working directory state. It also enables the agency-collaboration story: another user (an agency owner) reading the same artifacts in MMS's web UI without the original user shipping files over. [E4]

## Decision Drivers

**"Does the tool shape match what I already do well?"** Read/Write/Edit with read-before-modify gating is the de facto standard. Any deviation costs context budget and increases first-call failure rate. [E1]

**"Is the surface tight?"** Five file primitives plus the skill primitives is the right size. Each extra tool in `tools/list` is a slot the agent has to consider and reject on every selection step. [E1, E2]

**"Are paths stable and predictable?"** Canonical filenames the agent can name without consulting state — `marketing/05_positioning.md` always means the same artifact for this account. No timestamps, no UUIDs, no opaque keys. [E1, E4]

**"Can I discover what's here without remembering?"** A `list_files` (or equivalent) call has to exist, even if it's used rarely. Otherwise, multi-session continuity is unreachable. [E1]

**"Does the server enforce scope?"** The agent should not have to think about account prefixes, cross-tenant safety, or path traversal — the server resolves all of that from the bearer token. [E2, E5]

## Anti-Patterns

Explicit non-targets — surface shapes we are **not** designing for:

- **Content-as-blob tools (`save_artifact(path, content)` as a custom verb).** Generic-sounding verbs that don't map to a known pattern force the agent to read every tool description carefully and produce more tentative first calls. Use `write_file`, not `save_artifact`.
- **Opaque IDs as keys.** Asking the agent to track UUIDs returned from prior calls instead of human-readable paths breaks the symmetry with the local file API and makes session-resumption fragile.
- **Diff-format Edit (unified diff, search/replace blocks with line numbers).** Claude Code's Edit uses literal `old_string`/`new_string` exact-match, not a diff format. Models are trained on this shape; switching to a diff format costs accuracy.
- **Account prefix exposed to the agent.** Forcing the agent to send `accounts/{id}/marketing/05_positioning.md` instead of `marketing/05_positioning.md` leaks tenancy into prompt logic and increases blast radius if a prefix is ever wrong.
- **Bulk write tools.** A "save all eight artifacts at once" verb sounds efficient but breaks atomicity — one bad artifact kills the whole batch and the agent has to reason about partial-failure semantics it doesn't otherwise need.

## Evidence

Every claim above traces to one of the entries below. Sources are listed in full with URLs and access dates in `sources.md`.

- **E1** — Claude Code file-tool design (Read/Write/Edit, read-before-edit invariant, exact-string Edit, truncation-vs-throw context cost). Multiple independent confirmations from Anthropic docs, third-party deep-dives, and a March 2026 changelog incident showing the order-of-magnitude context cost of getting the response shape wrong.
- **E2** — MCP adoption and the Claude-Code-as-reference status. Multiple independent sources: every major agent ships MCP client support; Anthropic-led → industry-default transition between mid-2025 and early 2026; ~10K active public servers; ~97M monthly SDK downloads; ~4.2-hour integration time vs. ~18 hours pre-MCP.
- **E3** — Heterogeneous agent fleet and multi-tool stacks. Multiple independent confirmations: 70% of developers use 2–4 AI tools simultaneously; 15% use 5+; 14-tool benchmark roundups including Claude Code, Cursor, Aider, Cline, Windsurf, OpenCode, Codex CLI, Continue, Goose, Roo Code, Augment, Amp, Pi as live competitors.
- **E4** — Agentic workflow mainstreaming and multi-file edits. Multiple independent sources: 55% regular agent usage; 63.5% staff+ engineer adoption; multi-file edits as the default mode; agent-driven workflows across real codebases.
- **E5** — Context efficiency and tool-shape impact on first-call success. Pragmatic Engineer + Anthropic + Morphllm benchmark sources confirming the math on token cost, retry rate, and surface-shape mismatch.
