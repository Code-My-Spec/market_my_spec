# Vale CLI — Knowledge Reference

As of 2026-05-20. Vale v3.x (latest stable: v3.14.2 as of May 2026).

## What this is for

Phoenix shells out to the `vale` binary to lint a founder's polished post body against a per-account style configuration. Configuration (`.vale.ini` + styles) is stored on the account record and materialized to a temp directory at lint time. Results come back as JSON and are surfaced in the LiveView.

No Elixir wrapper library for Vale exists on Hex.pm. The integration pattern is `System.cmd/3` + `Jason.decode!/1`.

---

## 1. Installation

### macOS (dev)

```bash
brew install vale
```

Homebrew keeps Vale on `$PATH` and manages updates. No version pinning needed for local dev.

### Debian/Ubuntu Docker container (Hetzner prod)

There is no official `apt` package. Install from GitHub Releases in the `Dockerfile`:

```dockerfile
ARG VALE_VERSION=3.14.2
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates tar \
  && curl -sSL \
    "https://github.com/vale-cli/vale/releases/download/v${VALE_VERSION}/vale_${VALE_VERSION}_Linux_64-bit.tar.gz" \
    -o /tmp/vale.tar.gz \
  && tar -xzf /tmp/vale.tar.gz -C /usr/local/bin vale \
  && rm /tmp/vale.tar.gz \
  && vale --version
```

The release artifact naming convention is `vale_<VERSION>_Linux_64-bit.tar.gz` (x86-64) or `vale_<VERSION>_Linux_arm64.tar.gz` (ARM64). The Hetzner cax11 host is ARM64; use the arm64 asset if building natively on that box. For a multi-arch CI build targeting AMD64, use `64-bit`.

Pin `VALE_VERSION` as a build arg so version upgrades are a one-line diff.

**Docker image alternative:** `jdkato/vale:<version>` exists on Docker Hub but adds orchestration overhead. Prefer the binary-in-your-image approach since Vale is a tool for your app, not a sidecar.

---

## 2. Configuration file format (`.vale.ini`)

Vale uses INI format. The `StylesPath` is relative to the `.vale.ini` file's directory when given as a relative path — not relative to `$CWD`.

```ini
StylesPath = styles
MinAlertLevel = suggestion

Packages = Vale, write-good

[*.md]
BasedOnStyles = Vale, write-good
```

**Top-level keys:**

| Key | Type | Notes |
|---|---|---|
| `StylesPath` | path | Where Vale looks for style directories. Relative = relative to the `.vale.ini` file, not CWD. |
| `MinAlertLevel` | `suggestion` \| `warning` \| `error` | Filters output; alerts below this level are not emitted. Default: `suggestion`. |
| `Packages` | comma-separated strings | Packages to download via `vale sync`. Names from the official hub or external URLs. |
| `Vocab` | comma-separated strings | Vocabulary lists in `$StylesPath/config/vocabularies/`. |
| `IgnoredScopes` | comma-separated tags | Inline HTML tags to skip (e.g., `code`). |
| `SkippedScopes` | comma-separated tags | Block HTML tags to skip (e.g., `script`). |

**Format-specific sections:** Glob patterns define which files get which styles. More specific patterns override `[*]`.

```ini
[*]
BasedOnStyles = Vale

[*.md]
BasedOnStyles = Vale, write-good

[*.txt]
BasedOnStyles = Vale
```

`BasedOnStyles` lists style directories under `StylesPath` to activate.

**Extension mapping** (for non-standard extensions):

```ini
[formats]
mdx = md
```

**Directory layout after `vale sync`:**

```
.
├── .vale.ini
└── styles/
    ├── Vale/          ← built-in
    ├── write-good/    ← from Packages
    └── config/
        └── vocabularies/
            └── Base/
                ├── accept.txt
                └── reject.txt
```

---

## 3. Styles and packages

**Official package registry:** https://github.com/vale-cli/packages

Available packages (use these exact names in `Packages = ...`):

| Package name | Coverage |
|---|---|
| `Vale` | Built-in Vale rules |
| `Google` | Google Developer Documentation Style Guide |
| `Microsoft` | Microsoft Writing Style Guide |
| `write-good` | write-good linter |
| `proselint` | proselint rules |
| `alex` | alex linter (inclusive language) |
| `Joblint` | job-posting language |
| `Readability` | readability metrics |

External packages can be referenced by URL:

```ini
Packages = https://github.com/myorg/my-style/releases/download/v1.0/my-style.zip
```

**`vale sync`** downloads and unzips packages into `StylesPath`. It requires network access. Run it once at environment setup time, not at lint time.

**Vendoring (recommended for production):** After `vale sync`, commit the `styles/` directory into the repo or bake it into the Docker image. Vale then lints offline without network access. `vale sync` is a setup step, not a runtime dependency. The `.vale.ini` documentation recommends adding styles directories to `.gitignore` for open-source projects (to avoid bloat), but for this project's use case — account-specific styles baked into a temp dir — vendoring the style directories into the image is the right call.

**Per-account styles:** The account record stores either the raw `.vale.ini` content or a YAML representation that gets rendered to `.vale.ini`. The referenced style packages must already be present in a known location on the server (baked into the image). The account config points `StylesPath` at the vendored styles directory using an absolute path, sidestepping the relative-path resolution issue.

---

## 4. Running the CLI

### Lint a file

```bash
vale --config /path/to/.vale.ini --output JSON /path/to/prose.md
```

### Lint from stdin (recommended for Phoenix integration)

```bash
echo "Your prose here" | vale --config /path/to/.vale.ini --output JSON --ext=.md
```

`--ext=.md` tells Vale to treat stdin as Markdown. Without it, Vale will not know which format section to apply from `.vale.ini`.

### Key flags

| Flag | Purpose |
|---|---|
| `--config <path>` | Override config file search. Use an absolute path. |
| `--output JSON` | Machine-readable JSON output (see schema below). |
| `--no-exit` | Return exit code 0 even when errors are found. Use this so a non-zero exit doesn't raise in `System.cmd`. |
| `--ext=.md` | Assign extension to stdin input for format detection. |
| `--ignore-syntax` | Treat input as plain text, ignore markup. |
| `--no-global` | Skip loading the user's global `~/.vale.ini`. Always set this when running from Phoenix to avoid user-level config leaking in. |

**Recommended invocation from Phoenix:**

```bash
vale --config /tmp/lint-<id>/.vale.ini --output JSON --no-exit --no-global --ext=.md -
```

(The trailing `-` reads from stdin on some Vale versions. If that doesn't work, write prose to a temp file and pass the path.)

### JSON output schema

The output is a JSON object keyed by file path (or `"stdin"` when reading from stdin). Each value is an array of alert objects.

```json
{
  "/tmp/lint-abc123/prose.md": [
    {
      "Check": "write-good.Weasel",
      "Description": "",
      "Line": 3,
      "Link": "",
      "Message": "'very' is a weasel word and can almost always be removed",
      "Severity": "warning",
      "Span": [5, 8],
      "Hide": false
    }
  ]
}
```

Field reference:

| Field | Type | Notes |
|---|---|---|
| `Check` | string | Rule identifier: `"<Style>.<RuleName>"` |
| `Description` | string | Extended description (often empty) |
| `Line` | integer | 1-based line number |
| `Link` | string | URL for the rule (often empty) |
| `Message` | string | Human-readable alert text |
| `Severity` | string | `"suggestion"`, `"warning"`, or `"error"` |
| `Span` | [int, int] | `[start_col, end_col]`, 1-based columns |
| `Hide` | boolean | Whether Vale suppressed this alert in non-JSON output |

---

## 5. Linting plain prose (no Markdown)

Vale is format-aware. If you pipe raw textarea content, use `--ext=.md` to apply the `[*.md]` rules. This is correct for Reddit/Discourse posts since they render Markdown.

For truly unstructured text with no markup intent, use `--ext=.txt` and define a `[*.txt]` block in the config, or use `--ignore-syntax` to strip all format-awareness entirely. `--ignore-syntax` is a blunt instrument — it disables scope-based rule filtering, so rules that only apply inside headings or code fences won't scope correctly.

**Recommendation:** Write prose to a temp file named `prose.md` and pass the path. This avoids stdin extension guessing and produces a stable path key in the JSON output.

```bash
vale --config /tmp/lint-<id>/.vale.ini --output JSON --no-exit --no-global /tmp/lint-<id>/prose.md
```

---

## 5.5 Validating a `.vale.ini`

Use `vale ls-config` against the materialized config to verify it parses and references styles that exist. The command prints the resolved config to stdout on success and exits non-zero on a structural error:

```bash
vale --config /tmp/lint-<id>/.vale.ini ls-config
```

Use this at config-save time (story 736) to reject a malformed `.vale.ini` before it lands on the Account. On non-zero exit, surface the captured stderr to the founder.

---

## 6. Exit codes

| Code | Meaning |
|---|---|
| `0` | No alerts at or above `MinAlertLevel`, or `--no-exit` was set |
| `1` | One or more alerts found (suppressed by `--no-exit`) |
| `2` | Runtime error: config not found, `StylesPath` missing, malformed `.vale.ini` |

Always pass `--no-exit`. Check the JSON output for alerts rather than the exit code. Exit code 2 is a hard failure — catch it in Elixir and surface a config error to the user.

---

## 7. Performance / startup cost

Vale is a Go binary. Cold-start on a small input (a few paragraphs, a modest style set) is in the range of 50-200ms on modern hardware. This is fast enough for a per-request invocation from a Phoenix controller or LiveView action — it's comparable to a slow external HTTP call.

Loading many styles (Microsoft + Google + write-good + proselint together) increases startup cost modestly. For per-account configs that activate 2-3 styles, this is not a concern.

There is no long-running Vale server mode. If latency becomes a problem under load, the mitigation is to run the lint in a supervised `Task` so it doesn't block the LiveView process, and to add a per-account result cache keyed on a hash of `(prose, config_version)`. That optimization is not needed at v1 scale.

---

## 8. Elixir integration pattern

No Hex package wraps Vale. Use `System.cmd/3` directly.

```elixir
defmodule MarketMySpec.Linting.Vale do
  @moduledoc """
  Shells out to the `vale` CLI to lint prose against a per-account style config.

  The caller is responsible for materializing the temp directory before calling
  `lint/2` and cleaning it up afterward.
  """

  @vale_binary System.find_executable("vale") || "vale"

  @doc """
  Lints `prose` using the `.vale.ini` at `config_path`.

  Returns `{:ok, alerts}` where `alerts` is a list of alert maps,
  or `{:error, reason}` on config/runtime failure.
  """
  @spec lint(prose :: String.t(), config_path :: Path.t()) ::
          {:ok, list(map())} | {:error, String.t()}
  def lint(prose, config_path) do
    dir = Path.dirname(config_path)
    prose_path = Path.join(dir, "prose.md")
    File.write!(prose_path, prose)

    case System.cmd(
           @vale_binary,
           ["--config", config_path, "--output", "JSON", "--no-exit", "--no-global", prose_path],
           stderr_to_stdout: false
         ) do
      {json, 0} ->
        parse_output(json, prose_path)

      {json, 1} ->
        # --no-exit should suppress this, but handle defensively
        parse_output(json, prose_path)

      {error_output, 2} ->
        {:error, "vale config error: #{String.trim(error_output)}"}
    end
  end

  defp parse_output(json, prose_path) do
    case Jason.decode(json) do
      {:ok, result} ->
        alerts = result |> Map.get(prose_path, [])
        {:ok, alerts}

      {:error, _} ->
        {:error, "vale produced non-JSON output: #{String.slice(json, 0, 200)}"}
    end
  end
end
```

**Temp directory lifecycle:**

```elixir
defmodule MarketMySpec.Linting.TempDir do
  def with_lint_dir(fun) do
    dir = Path.join(System.tmp_dir!(), "vale-#{:crypto.strong_rand_bytes(8) |> Base.encode16()}")
    File.mkdir_p!(dir)

    try do
      fun.(dir)
    after
      File.rm_rf!(dir)
    end
  end
end
```

Caller:

```elixir
TempDir.with_lint_dir(fn dir ->
  config_path = Path.join(dir, ".vale.ini")
  File.write!(config_path, account.vale_config)
  Vale.lint(touchpoint.body, config_path)
end)
```

**`StylesPath` in the account config must be absolute**, pointing at the vendored styles baked into the image (e.g., `/app/priv/vale/styles`). Do not use a relative path when materializing configs to arbitrary temp directories — relative paths resolve relative to the `.vale.ini` file's directory, which is a fresh temp dir with no styles in it.

**Security note:** `System.cmd/3` does not invoke a shell; arguments are passed directly to the OS exec. This means the prose content written to a temp file — not interpolated into the command string — is not a command injection risk. Never interpolate user input into the command list. The account's `.vale.ini` content should be stored as a trusted config (set by the account owner, not arbitrary user input); treat it accordingly.

Sobelow (`{:sobelow, "~> 0.13"}` is already in `mix.exs`) will flag any `System.cmd` call for review. Add a `# sobelow_skip ["RCE.Shell"]` annotation with a comment if Sobelow raises a false positive on the path-only usage.

---

## 9. Gotchas

**`StylesPath` is relative to the config file, not `$CWD`.** When Phoenix materializes a `.vale.ini` into `/tmp/lint-abc/`, a `StylesPath = styles` entry looks for `/tmp/lint-abc/styles/` — which doesn't exist. Use an absolute path: `StylesPath = /app/priv/vale/styles`.

**`vale sync` at runtime is wrong.** Never call `vale sync` inside a Phoenix request. Sync requires network, writes to the filesystem, and is slow. Run it once when building the Docker image and bake the results in.

**Missing styles = silent no-op.** If `StylesPath` points to a directory that exists but a style listed in `BasedOnStyles` is not present in it, Vale may emit no alerts rather than an error. Validate at startup that the vendored styles directory contains the expected subdirectories.

**`--no-global` is required.** Without it, Vale will merge in the global `~/.vale.ini` of whatever user the Phoenix process runs as inside the container. This can produce unexpected results.

**Exit code 2 is a hard config error.** It does not produce JSON. Catch it and return an error to the user rather than trying to `Jason.decode!` the output.

**`vale` must be on `$PATH` of the Phoenix release.** In a Docker release build, the `vale` binary installed in `/usr/local/bin/` during the build stage must be present in the final runtime stage. If using a multi-stage Dockerfile, copy the binary explicitly:

```dockerfile
COPY --from=builder /usr/local/bin/vale /usr/local/bin/vale
```

**`System.find_executable("vale")` can return `nil`** if `$PATH` is minimal in the release environment. Hard-code the binary path or set a `VALE_BIN` environment variable rather than relying on `find_executable` at module load time.

**Concurrent lint requests share no state.** Each invocation writes to a unique temp directory, so concurrency is safe. The only shared resource is the vendored styles directory, which is read-only after Docker image build.

---

## Sources

- Vale official docs: https://vale.sh/docs
- Vale install: https://vale.sh/docs/install
- Vale CLI flags: https://vale.sh/docs/cli
- Vale .vale.ini reference: https://vale.sh/docs/vale-ini
- Vale packages registry: https://github.com/vale-cli/packages
- Vale GitHub releases: https://github.com/vale-cli/vale/releases
- ALE editor integration (JSON schema reference): https://github.com/dense-analysis/ale/pull/1232/files
- System.cmd security (Elixir issue): https://github.com/elixir-lang/elixir/issues/2251
- Sobelow (static analysis for Phoenix): https://hexdocs.pm/sobelow/api-reference.html
- Prose linting with Vale (Meilisearch): https://www.meilisearch.com/blog/prose-linting-with-vale
