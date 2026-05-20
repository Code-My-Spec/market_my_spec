# Auto-Update Options for MMS Agent

Survey of approaches to keep the installed binary current, with a recommendation.

## Option 1: Pure `brew upgrade`

Users run `brew upgrade mms-agent` manually or on a schedule. Homebrew updates the
formula from the tap and re-downloads the binary.

**How it works:**
1. Maintainer bumps `version`, `url`, and `sha256` in `mms-agent.rb` and pushes to
   `homebrew-mms-agent`.
2. User runs `brew update && brew upgrade mms-agent`.
3. Done.

**Pros:** Zero code in the binary. Homebrew handles download, checksum, PATH swap.

**Cons:** Entirely user-initiated. Users running an old binary will never update unless
they remember to run the command. No notification that a newer version exists.

## Option 2: brew auto-upgrade via cron

A variation: users set up a cron job or LaunchAgent that calls `brew upgrade` daily.
Homebrew itself does not schedule upgrades automatically on macOS.

**Pros:** "Set and forget" for motivated users who configure it.

**Cons:** Requires user setup. Not something we control. LaunchAgents are non-trivial.
Not a real distribution strategy.

## Option 3: In-Binary Self-Update

The binary checks the GitHub Releases API on startup (or on `mms-agent update`), downloads
the newer asset for the running platform, does an atomic file swap, and re-execs itself.

**Pattern (language-agnostic):**

```
1. GET https://api.github.com/repos/market-my-spec/mms-agent/releases/latest
   -> extract "tag_name" (e.g. "v0.2.0") and browser_download_url for the current platform asset
2. Compare tag_name against the version compiled into the binary (Application.spec/2 or a
   module attribute set at build time).
3. If newer: download to a temp file, chmod +x, rename to replace the running binary,
   exec the new binary with the original args.
```

**In Elixir (inside a Burrito binary):**

```elixir
defmodule MarketMySpecAgent.Updater do
  @current_version Mix.Project.config()[:version]
  @releases_url "https://api.github.com/repos/market-my-spec/mms-agent/releases/latest"

  def check_and_update do
    with {:ok, %{body: body}} <- Req.get(@releases_url),
         %{"tag_name" => tag, "assets" => assets} <- Jason.decode!(body),
         version = String.trim_leading(tag, "v"),
         true <- version_newer?(version, @current_version),
         asset when not is_nil(asset) <- find_asset(assets) do
      do_update(asset["browser_download_url"])
    else
      _ -> :already_current
    end
  end

  defp do_update(url) do
    tmp = System.tmp_dir!() |> Path.join("mms-agent-new")
    {:ok, _} = Req.get(url, into: File.stream!(tmp))
    File.chmod!(tmp, 0o755)
    self_path = :erts_internal.beam_file()  # or read from argv[0]
    File.rename!(tmp, self_path)
    # Re-exec with same args (POSIX exec(2) replacement)
    System.cmd(self_path, System.argv(), into: IO.stream())
    System.halt(0)
  end

  defp find_asset(assets) do
    platform_suffix = platform_asset_suffix()
    Enum.find(assets, &String.ends_with?(&1["name"], platform_suffix))
  end

  defp platform_asset_suffix do
    arch = :erlang.system_info(:system_architecture) |> to_string()
    cond do
      String.contains?(arch, "darwin") and String.contains?(arch, "aarch64") -> "_macos_m1"
      String.contains?(arch, "darwin") -> "_macos"
      String.contains?(arch, "linux") and String.contains?(arch, "aarch64") -> "_linux_aarch64"
      true -> "_linux"
    end
  end

  defp version_newer?(remote, current) do
    Version.compare(remote, current) == :gt
  end
end
```

**Caveats for Burrito binaries:**
- Getting `self_path` from inside a Burrito binary requires reading `System.argv()` or
  using `:erts_internal` — the Burrito launcher knows its own path, but the BEAM does not
  have an `os.Executable()` equivalent. The cleanest approach: pass `argv[0]` through as
  an env var in the Zig launcher, or compute it from `System.get_env("_")` on unix.
- After `File.rename!`, the new binary is not in a temporary keychained quarantine because
  Homebrew already cleared quarantine on first install (see `signing-and-gatekeeper.md`).
- macOS Gatekeeper will block unsigned binaries downloaded at runtime — the binary must be
  signed or the user must already have cleared quarantine (see signing notes below).

**Pros:** Users get the latest version automatically. Works on Linux too.

**Cons:** Significant implementation work. Gatekeeper is a real blocker for unsigned
binaries (see Option 3a). The self-replace dance on a running process is tricky.

## Option 4 (Recommended): Phone-Home Version Check + brew upgrade Prompt

On each invocation of `mms-agent` (or at minimum on `mms-agent status`), the binary
calls a lightweight `/api/agent/version` endpoint on `marketmyspec.com` and compares the
response against its compiled-in version string.

```
GET https://marketmyspec.com/api/agent/version
Content-Type: application/json

Response: {"latest": "0.2.0", "min_supported": "0.1.0"}
```

If `latest > current`, print a one-line notice:

```
Notice: mms-agent v0.2.0 is available. Run: brew upgrade mms-agent
```

The update itself is still done by Homebrew, which handles the download, checksum
verification, PATH swap, and Gatekeeper quarantine clearance automatically.

**Why this wins for MMS Agent:**

- No self-replace complexity in the binary. No Gatekeeper re-signing on download.
- Homebrew handles every trust concern that Apple cares about.
- The version check is a single `Req.get/1` call — trivially implemented alongside
  existing `status` logic.
- Cache the check result to `~/.mms-agent/version_check.json` with a TTL of 24h to
  avoid hammering the server.
- The server-side endpoint is a one-line Phoenix controller action — no new infrastructure.
- Works identically on macOS and Linux.

**When to add in-binary self-update (Option 3):** If MMS Agent ever ships outside
Homebrew (direct download, apt, etc.) and needs to update users who installed via those
channels, revisit Option 3 at that point.

## Gatekeeper and Self-Downloaded Binaries

If the binary downloads and replaces itself (Option 3), the replacement is a fresh
quarantined download from an unknown source as far as macOS is concerned. Even if the
original Homebrew install cleared quarantine, the newly downloaded replacement binary
will be quarantined again unless:

1. It is signed with the same Developer ID Application certificate, and
2. It has been notarized by Apple.

Without that, users on macOS 13+ will see "Apple cannot verify..." and the new binary
will be blocked. This is the primary reason to prefer Option 4 (prompt + brew upgrade)
for the first release.

## References

- [go-github-selfupdate pattern](https://github.com/rhysd/go-github-selfupdate)
- [Burrito readme](https://hexdocs.pm/burrito/readme.html)
- [Apple Gatekeeper overview](https://developer.apple.com/developer-id/)
