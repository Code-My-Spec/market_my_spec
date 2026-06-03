# Problem-Discovery Skill Guides the Agent Through the Pipeline

## Status
Accepted

## Context
The problem-discovery feature exposes a 5-stage pipeline (Frame → Gather → Cluster → Score → Red-team → Board) through MCP tools (see `problem-discovery-clustering.md` for the architecture, `problem-discovery-data-sources.md` for the source layer). The agent has 14+ tools available to drive these stages, label Candidates, merge/split clusters, and prosecute candidates.

Two outstanding questions about how the agent uses these tools coherently:

1. **How does the agent know which tool to call at which stage?** The MCP tool list is just a list — without orientation, the agent might run Score before Cluster, skip the 3-pass refinement, or fail to use probe-mode Gather during Frame composition.

2. **Where does the semantic structure live?** Some pipeline phases have non-obvious procedure (Frame: Sales-Safari vocabulary audits; Cluster review: 3-pass refinement — describe pain → consolidate/split → label; Red-team: per-Candidate conversational prosecution). If this lives only in the agent's training, it gets done inconsistently; if it lives in long-form prompts the agent constructs each time, the agent reinvents it per session.

Looking at the existing codebase, `MarketMySpec.Skills.MarketingStrategy` solves the same shape of problem for marketing-strategy work. It exposes a `SkillOrientation` MCP resource (an enumeration of the skill's phases and tool surface) plus per-step `Step` resources (long-form instructions for each phase). The agent calls `start_interview` to begin a guided session; subsequent agent turns read the relevant step resources and invoke the tools they name.

The same shape fits problem-discovery. The skill is the agent's interface to the pipeline; the MCP tools are the actions the skill walks the agent through.

### Options considered

**No skill — agent reads ADRs and constructs its own procedure.**
- Pro: One less moving part.
- Con: The semantic structure (Sales-Safari, 3-pass refinement, per-Candidate prosecution) gets reinvented or forgotten each session.
- Con: Cross-session inconsistency in how Frames are composed, how clusters are refined, how Red-team verdicts get written.
- Verdict: Rejected. The skill is exactly the right place to durably encode procedure that's load-bearing for product quality.

**Skill as plain Markdown in `.code_my_spec/knowledge/problem_research/` (resolved question 1b113169).**
- Pro: Zero new infrastructure.
- Con: Not addressable via MCP — the agent has to know to read those files, and which file applies to which phase.
- Con: Diverges from the `MarketingStrategy.Resources.{SkillOrientation, Step}` pattern; future readers maintain two patterns.
- Verdict: Rejected.

**Skill modeled as `Skills.ProblemDiscovery` + `McpServers.ProblemDiscovery.Resources.{SkillOrientation, Step}`, mirroring MarketingStrategy.**
- Pro: Consistent with existing skill pattern; one mental model for "how skills are organized."
- Pro: Orientation is one MCP resource fetch; per-phase steps are addressable resources the agent reads when entering a phase.
- Pro: Tool surface stays in `McpServers.ProblemDiscovery.Tools.*` (already created during architecture mapping); resources sit alongside.
- Verdict: Adopted.

## Decision

### Components
- **`MarketMySpec.Skills.ProblemDiscovery`** — skill module, peer of `MarketMySpec.Skills.MarketingStrategy` under `MarketMySpec.Skills`. Holds the skill's name, registered phases, and orientation text body.
- **`MarketMySpec.McpServers.ProblemDiscovery.Resources.SkillOrientation`** — MCP resource exposing the skill's orientation: pipeline phases, MCP tools per phase, surface map (skill-driven vs founder-direct LiveView).
- **`MarketMySpec.McpServers.ProblemDiscovery.Resources.Step`** — MCP resource exposing per-phase step instructions. Phases enumerated below.

These mirror `MarketMySpec.McpServers.MarketingStrategy.Resources.{SkillOrientation, Step}` exactly in shape and registration.

### Phases the skill enumerates

| Phase | Skill responsibility | Primary MCP tools |
|---|---|---|
| **Frame** | Sales-Safari-style vocabulary audit; iterative multi-turn session producing a Frame artifact with description, saved searches, money_gate threshold, and kill_condition. Supports probe-mode Gather rounds against draft saved searches before commit. | `ListFrames`, `CreateFrame`, `UpdateFrame`, `GetFrame`, `RunGather` (probe mode) |
| **Gather** | Per-saved-search execution; reports N gathered / M failed per saved search. Additive: adding a new saved search to a committed Frame gathers only the new source. | `RunGather` |
| **Cluster review** | 3-pass refinement: (1) for each JobPosting in each Candidate, agent writes a structured `pain_descriptor` via `SetPainDescriptor`; (2) agent uses descriptor similarity to consolidate (`MergeCandidates`) or split (`SplitCandidate`) Candidates; (3) agent assigns a descriptor-grounded name via `LabelCandidate`. KMeans seeds the initial partition; the descriptor pass produces the final semantic clustering. | `RunCluster`, `ListCandidates`, `SetPainDescriptor`, `MergeCandidates`, `SplitCandidate`, `LabelCandidate` |
| **Score** | Apply Frame's money_gate per JobPosting. In-place reclassification of PaidJobSignal records; recomputes per-Candidate aggregated scores. Never refetches the corpus. | `RunScore`, `ListPaidJobSignals` |
| **Red-team** | One Candidate at a time, conversational. Agent reads the Candidate's evidence (member JobPostings + gated_in PaidJobSignals) and produces a RedTeamVerdict that overwrites Score's verdict on the Board. | `RedTeamCandidate`, `ListCandidates` |
| **Board** | Assembled view over Candidates + final verdicts; kill_condition status. Founder consumes via the `ProblemDiscoveryLive.Frame` LiveView (the killable-in-one-click table); agent reads via `GetBoard` to report status. | `GetBoard` |

### Surface map (what the skill clarifies)
- **Skill-driven (agent flows)**: Frame composition iteration, probe-mode Gather, Cluster 3-pass refinement, Red-team prosecution
- **Founder-direct (LiveView)**: Frames index / compose (`ProblemDiscoveryLive.Frames`), Frame detail + Board with kill buttons (`ProblemDiscoveryLive.Frame`)

Both coexist. The founder can compose Frames in the LiveView or have the agent do it through the skill. The Board UI and the `GetBoard` MCP tool are two views of the same projection.

### What the skill is NOT
- Not a state machine — the agent does not have to traverse phases in order. The skill orientation describes the canonical sequence; the agent picks the appropriate phase based on session context.
- Not LLM-bearing on MMS's side — the skill provides instructions and tool naming, but no model calls happen from MMS. The agent does all the model work.
- Not a replacement for ADRs — the skill encodes how to USE the system; ADRs encode why it's built that way. Read both.

## Consequences
- **Pro:** Agent gets a consistent procedure across sessions. Sales-Safari vocab audits and 3-pass cluster refinement don't get skipped or reinvented.
- **Pro:** One pattern for skill organization across the codebase (matches MarketingStrategy).
- **Pro:** Phase-level resources are addressable — agent reads only the step it needs, not the whole skill.
- **Pro:** Adding a future skill phase (e.g., "Distribution" — push surviving Candidates into a marketing pipeline) is a new Step resource + tool registration, no architectural surgery.
- **Con:** Skill body has to be written and maintained alongside the tools. If a tool signature changes, the skill step naming it must be updated. Mitigated by the small number of tools.
- **Con:** Two surfaces for the same actions (skill-driven via agent vs LiveView for founder). Documentation must keep the surface map clear or founders get confused about "which one is canonical." Resolved by the surface map in the orientation resource.

See `problem-discovery-clustering.md` for the pipeline architecture, `problem-discovery-data-sources.md` for the source layer, `openai-embeddings.md` for the model-call exemption.
