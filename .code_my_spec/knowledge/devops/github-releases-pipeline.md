# GitHub Releases Pipeline

CI matrix that builds all four Burrito targets and publishes them to a GitHub Release.

## Overview

The workflow triggers on a version tag push (`v*`), runs four parallel jobs (one per Burrito
target), and then assembles a release with all four binaries plus a SHA256 manifest.

Zig is required. Burrito v1.5+ needs Zig **0.15.2** — install it during the build job before
running `mix release`.
Source: [Burrito readme](https://hexdocs.pm/burrito/readme.html)

## Target Matrix

From `mix.exs`:

| `BURRITO_TARGET` | OS | CPU | GitHub runner |
|---|---|---|---|
| `macos_m1` | Darwin | aarch64 | `macos-14` (Apple M1) |
| `macos` | Darwin | x86_64 | `macos-13` (Intel) |
| `linux` | Linux | x86_64 | `ubuntu-22.04` |
| `linux_aarch64` | Linux | aarch64 | `ubuntu-22.04` + QEMU, or `ubuntu-22.04-arm` |

Cross-compilation note: Burrito can cross-compile via Zig from any host to any target, but
native runners are simpler. For Linux aarch64, use a native ARM runner (`ubuntu-22.04-arm`
if your GitHub plan supports it) rather than QEMU emulation, which is slow for a 37MB BEAM
payload.

## Workflow YAML

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - "v*"

jobs:
  build:
    name: Build ${{ matrix.burrito_target }}
    runs-on: ${{ matrix.runner }}
    strategy:
      matrix:
        include:
          - burrito_target: macos_m1
            runner: macos-14
            output_name: market_my_spec_agent_macos_m1
          - burrito_target: macos
            runner: macos-13
            output_name: market_my_spec_agent_macos
          - burrito_target: linux
            runner: ubuntu-22.04
            output_name: market_my_spec_agent_linux
          - burrito_target: linux_aarch64
            runner: ubuntu-22.04-arm
            output_name: market_my_spec_agent_linux_aarch64

    steps:
      - uses: actions/checkout@v4

      - name: Install Erlang and Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: "27"
          elixir-version: "1.17"

      - name: Install Zig 0.15.2
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: "0.15.2"

      - name: Verify Zig in PATH
        run: zig version

      - name: Install Mix deps
        run: MIX_ENV=prod_agent mix do deps.get, deps.compile
        env:
          MIX_ENV: prod_agent

      - name: Build Burrito binary
        run: MIX_ENV=prod_agent mix release market_my_spec_agent
        env:
          MIX_ENV: prod_agent
          BURRITO_TARGET: ${{ matrix.burrito_target }}

      - name: Compute SHA256
        run: |
          shasum -a 256 burrito_out/${{ matrix.output_name }} \
            | awk '{print $1}' > burrito_out/${{ matrix.output_name }}.sha256

      - name: Upload binary artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.output_name }}
          path: |
            burrito_out/${{ matrix.output_name }}
            burrito_out/${{ matrix.output_name }}.sha256

  release:
    name: Create GitHub Release
    needs: build
    runs-on: ubuntu-22.04
    permissions:
      contents: write

    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts/
          merge-multiple: true

      - name: List artifacts
        run: ls -lh artifacts/

      - name: Build SHA256 manifest
        run: |
          cat artifacts/*.sha256 > artifacts/SHA256SUMS.txt
          cat artifacts/SHA256SUMS.txt

      - name: Create GitHub Release and upload assets
        run: |
          gh release create "${{ github.ref_name }}" \
            artifacts/market_my_spec_agent_macos_m1 \
            artifacts/market_my_spec_agent_macos \
            artifacts/market_my_spec_agent_linux \
            artifacts/market_my_spec_agent_linux_aarch64 \
            artifacts/SHA256SUMS.txt \
            --repo "${{ github.repository }}" \
            --title "MMS Agent ${{ github.ref_name }}" \
            --notes "MMS Agent release ${{ github.ref_name }}"
        env:
          GH_TOKEN: ${{ github.token }}
```

## How BURRITO_TARGET Works

Setting `BURRITO_TARGET=macos_m1` in the environment causes Burrito's `burrito_targets/0`
function in `mix.exs` to return only the `[macos_m1: [os: :darwin, cpu: :aarch64]]` entry,
so only that one binary is compiled. Each matrix job sets a different value, so four jobs
run in parallel, each producing one binary.

Output path per job: `burrito_out/market_my_spec_agent_<target>`.

## Secrets Required

| Secret | Purpose |
|---|---|
| `GITHUB_TOKEN` (built-in) | Create release, upload assets |

The built-in `GITHUB_TOKEN` with `contents: write` permission is sufficient for
`gh release create`. No PAT needed for releases on the same repo.

## SHA256 for Homebrew Formula

After the release workflow completes, the SHA256 for each binary is in `SHA256SUMS.txt`
on the release page. Copy these into the Homebrew formula (see
`homebrew-binary-formula.md`).

To automate formula bumping: add a third job that calls the GitHub API to update the
`mms-agent.rb` file in the `homebrew-mms-agent` tap repo with the new version and
checksums, then opens a PR or pushes directly to `main`.

## Prior Art: CodeMySpec PackageExtension

The sibling `code_my_spec` repo does release publishing in Elixir:
`code_my_spec/lib_cli/code_my_spec_cli/release/package_extension.ex`. Key patterns:

- `System.cmd("gh", ["release", "create", tag, binary_path, ...])` — same `gh` CLI approach
- `PUBLISH_RELEASE=true` env gate so CI releases don't accidentally fire on local builds
- Target naming: `darwin-arm64`, `darwin-x64`, `linux-arm64`, `linux-x64`
  (MMS Agent uses Burrito's own naming: `macos_m1`, `macos`, `linux`, `linux_aarch64`)

The MMS Agent approach moves this logic into the GitHub Actions workflow rather than a
Burrito post-build step, which is simpler for multi-runner matrix builds.

## References

- [Burrito readme - BURRITO_TARGET](https://hexdocs.pm/burrito/readme.html)
- [setup-beam GitHub Action](https://github.com/erlef/setup-beam)
- [setup-zig GitHub Action](https://github.com/goto-bus-stop/setup-zig)
- [Automating multi-platform releases with GitHub Actions](https://dev.to/eugenebabichenko/automated-multi-platform-releases-with-github-actions-1abg)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
