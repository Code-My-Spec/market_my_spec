# CodeMySpec — Agent Workflow Guide

CodeMySpec is a requirements-driven development harness. It models your project as a
graph of **stories**, **components**, and **requirements**, then guides you through
building each piece in the right order: specs → tests → implementations → reviews → QA.

## Core Loop

```
get_next_requirement → start_task → do the work → (auto-evaluate) → repeat
```

### Step 1: Get Your Next Requirement

Call **`get_next_requirement`**. It syncs the filesystem, computes the requirement graph,
and returns the single highest-priority unsatisfied requirement whose prerequisites are met.

Three possible responses:
- **init_required** — project not linked yet. Follow the bootstrap checklist.
- **sync_required** — project exists but has no stories/components. Create them first.
- **next requirement** — the requirement to work on, with entity type, name, and ID.

### Step 2: Start the Task

Call **`start_task`** with the requirement's `requirement_name`, `entity_type`, and
`entity_id` (or `module_name` for components). This creates a task on your session and
returns a **detailed work prompt** containing:

- Which files to read (specs, rules, existing code)
- The exact file path to write to
- Templates and format requirements
- Design rules and coding standards for the component type
- Similar components to reference for patterns

**Follow the prompt.** It is tailored to the specific component and requirement.

### Step 3: Do the Work

The requirement types you'll encounter, in dependency order:

| Requirement | What You Produce |
|---|---|
| `spec_file` | Module specification in `.code_my_spec/spec/` |
| `spec_valid` | Fix validation errors in the spec |
| `review_file` | Design review for a context and its children |
| `review_valid` | Fix validation errors in the review |
| `test_file` | Test file following TDD — write tests before implementation |
| `test_spec_alignment` | Ensure tests cover all spec assertions |
| `implementation_file` | Implementation code in `lib/` |
| `tests_passing` | Fix failing tests |
| `bdd_specs_exist` | BDD scenario files for a story's acceptance criteria |
| `bdd_specs_passing` | Fix failing BDD specs |
| `qa_complete` | QA brief and results for a story |

### Step 4: Automatic Evaluation

When you finish (or the session stops), the harness evaluates your output:
- Does the file exist at the expected path?
- Does it parse/validate against the document schema?
- Do tests compile and pass?
- Is the test aligned with the spec's assertions?

If evaluation finds problems, you receive structured feedback. Fix and continue.

## Project Structure

```
.code_my_spec/
├── architecture/     Component graph, dependency diagram, decisions
├── spec/             Module specifications (*.spec.md)
├── rules/            Design and test rules by component type
├── status/           Implementation status per component
├── issues/           Known bugs (incoming/, accepted/, dismissed/)
├── knowledge/        Project-specific research
├── framework/        Framework reference docs
├── design/           Design system assets
├── qa/               QA briefs, results, journey plans
└── integrations/     Integration specs
```

## MCP Tools Reference

### Requirements & Tasks
| Tool | Purpose |
|---|---|
| `get_next_requirement` | Get the next thing to work on |
| `start_task` | Begin work — returns the detailed prompt |
| `list_requirements` | See all requirements and their status |
| `sync_project` | Re-sync filesystem state |
| `evaluate_task` | Manually trigger evaluation |
| `list_tasks` | See active/completed tasks |

### Stories & Architecture
| Tool | Purpose |
|---|---|
| `list_stories` / `list_story_titles` | View user stories |
| `set_story_component` | Link a story to its surface component |
| `analyze_stories` | Analyze stories for architecture mapping |
| `validate_dependency_graph` | Check for circular dependencies |

### Issues
| Tool | Purpose |
|---|---|
| `list_issues` / `get_issue` | View issues |
| `create_issue` | Report a new issue |
| `accept_issue` / `dismiss_issue` | Triage incoming issues |
| `resolve_issue` | Mark an issue as fixed |

### Bootstrap (first-time setup)
| Tool | Purpose |
|---|---|
| `list_projects` | See available projects |
| `init_project` | Link this directory to a project |
| `install_claude_md` | Create/update CLAUDE.md managed section |
| `install_agents_md` | Create/update this file |
| `install_rules` | Copy design and test rules |

## Component Types

The harness supports these component types, each with their own requirement
chain and design rules:

- **context** — Domain boundary with public API (`.code_my_spec/rules/context_design.md`)
- **schema** — Data structure with validation (`.code_my_spec/rules/schema_design.md`)
- **repository** — Data access layer (`.code_my_spec/rules/repository_design.md`)
- **liveview** — Phoenix LiveView page (`.code_my_spec/rules/liveview_design.md`)
- **liveview_component** — Reusable LiveView component (`.code_my_spec/rules/liveview_component_design.md`)
- **live_context** — LiveView grouping (spec + review only)
- **controller** — Phoenix HTTP handler
- **genserver** — Stateful process
- **task** — Background job
- **behaviour** — Callback definition (spec + implementation only)

General Elixir rules: `.code_my_spec/rules/elixir_design.md`, `.code_my_spec/rules/elixir_test.md`

## Key Principles

1. **The graph is the plan.** Don't decide what to work on — ask `get_next_requirement`.
2. **Specs before code.** Every component gets a specification first. Tests are written
   from the spec. Implementation satisfies the tests.
3. **Read the task prompt.** It contains everything you need: templates, rules, file paths,
   and patterns from similar components.
4. **One requirement at a time.** Complete it, let evaluation run, then get the next one.
5. **Issues are first-class.** If you find a problem, create an issue. Don't fix unrelated
   things inline.

## Architecture Reference

| Need | File |
|---|---|
| Component graph with types and deps | `.code_my_spec/architecture/overview.md` |
| Namespace hierarchy | `.code_my_spec/architecture/namespace_hierarchy.md` |
| Dependency diagram (Mermaid) | `.code_my_spec/architecture/dependency_graph.mmd` |
| Architecture decisions | `.code_my_spec/architecture/decisions/` |
| Implementation status | `.code_my_spec/status/market_my_spec.md` |
