# Use Vale for Touchpoint Prose Linting

## Status
Accepted

## Context
A Touchpoint's `polished_body` (story 707) is the plain text a founder copy-pastes onto Reddit / ElixirForum. Voice consistency, banned-phrase enforcement (e.g. no em dashes — they trip Reddit spam filters per `feedback_reddit_formatting.md`), and tone discipline currently live in scattered memory notes and skill prompts. We need an automated check so a founder editing a touchpoint sees concrete suggestions before posting.

[Vale](https://vale.sh) is a syntax-aware, configurable prose linter. It is the de facto standard for prose CI in technical writing (used by GitLab, Microsoft, Red Hat, Linux kernel docs). It is a single-binary Go program with no runtime dependencies. Configuration is a `.vale.ini` plus a `StylesPath` directory of YAML rule files, which makes "paste your config and rules" a viable v1 UX.

Alternatives considered:
- **proselint** (Python) — narrower rule set, Python runtime in the Docker image, no first-class custom-rule story.
- **write-good** (Node) — small rule set, Node runtime, not extensible enough for our voice guide.
- **LLM-as-linter** — every-save token cost, non-deterministic, hard to encode rules like "no em dashes." Vale gives deterministic, fast, free feedback; an LLM polish pass still happens upstream in the agent chat.

## Decision

### Tool
Use the Vale CLI shelled out from Phoenix via `System.cmd/3`. Parse the JSON output with `Jason.decode/1` and surface alerts to the LiveView.

### Per-account configuration
Each Account owns a Vale configuration: a `.vale.ini` body plus a flat collection of style rule files (YAML, one rule per file, in a single virtual `StylesPath`). v1 UX is paste-in — the founder pastes their `.vale.ini` and rule files into a settings screen, and they are persisted on the Account. No `vale sync` / network fetch at runtime.

The config lives on the Account (not a project) because Market My Spec does not yet have a project concept; one founder, one voice guide.

### Runtime invocation
Per lint request:
1. Materialize the account's `.vale.ini` to a fresh temp directory, rewriting its `StylesPath` to the absolute path of the styles tree the lint should use (see "Styles location" below).
2. Write the prose to `prose.md` in the same temp dir (Vale is format-aware; treating prose as Markdown matches how it will be posted on Reddit / ElixirForum).
3. Run `vale --config <tmp>/.vale.ini --output JSON --no-exit --no-global <tmp>/prose.md`.
4. Decode JSON, return alerts keyed by the prose path.
5. Delete the temp dir (even on error).

`--no-exit` keeps `System.cmd` from raising on alerts. `--no-global` blocks the container user's `~/.vale.ini` from bleeding in. Exit code 2 is a hard config failure (no JSON emitted) — surface it as a config error, not an alert list.

No long-running Vale process, no port wrapper, no caching in v1. Vale's cold start is 50-200ms on small inputs — fine for a user-initiated lint button.

### Styles location
Vale's `StylesPath` resolves relative to the `.vale.ini` file's directory and **silently no-ops** if styles are missing. The temp-dir-per-request scheme therefore cannot use a relative `StylesPath` against a freshly created empty temp dir — the lint will succeed with zero alerts and look like a clean pass.

The fix: standard packages (Vale, write-good, proselint, alex, Microsoft, Google) are vendored into the Docker image at `/app/priv/vale/styles` via `vale sync` at build time. Per-account `.vale.ini`s are rewritten on materialization to set `StylesPath = /app/priv/vale/styles`. The founder pastes a `.vale.ini` that names packages and rule activations; they do not paste rule YAML in v1. Custom rules (e.g., a "no em dashes" project-specific check) are deferred — if needed, they ship as a "House" package vendored into the image alongside the standard packages.

`vale sync` is a build-time step only; never invoked at request time (it requires network and writes to the filesystem). See `.code_my_spec/knowledge/vale-cli.md` §3 and §9 for the full constraint set.

### Installation
- **Dev (macOS):** `brew install vale`
- **Deployed (Hetzner Docker per `hetzner-deployment.md`):** install via official tarball in the Dockerfile, pinning a version. Vale is not in Debian's apt repos at a useful version.

### When linting runs
v1: on explicit user action (a "Lint" button on the Touchpoint edit form) and on save of `polished_body`. Not on every keystroke. Results are advisory; failing lints do not block save.

## Consequences
- **Pro:** Deterministic, free, fast feedback. The "no em dashes" rule and the rest of `feedback_reddit_formatting.md` become enforceable instead of remembered.
- **Pro:** Paste-in config is the lowest-friction v1 — no rule-editor UI to build. Founders who already use Vale can copy their existing config in minutes.
- **Pro:** Per-account scoping leaves room for multi-tenant expansion without a migration.
- **Con:** Shell-out per request is a small operational surface — temp file cleanup, Vale binary present in the image, exit-code handling. The risk is contained because Vale is read-only and runs on user-supplied prose, not arbitrary input from the network.
- **Con:** No `vale sync` means we can't use the third-party package registry (Microsoft, Google, write-good styles) without the founder vendoring them by paste. Acceptable for v1; revisit if founders ask for it.
- **Con:** Vale binary must be in the prod and UAT images. Add to the Dockerfile alongside the existing apt installs.

See `.code_my_spec/knowledge/vale-cli.md` for install commands, `.vale.ini` schema, JSON output shape, exit-code semantics, and the Elixir shell-out pattern.
