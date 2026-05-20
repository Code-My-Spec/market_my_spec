# Homebrew Binary Formula

How to ship the `mms-agent` precompiled binary via a Homebrew tap.

## Tap Repo Layout

Homebrew requires the GitHub repo to be named `homebrew-<tap>`. For MMS Agent:

```
GitHub repo: market-my-spec/homebrew-mms-agent
  └── Formula/
      └── mms-agent.rb
```

Users install with:

```bash
brew tap market-my-spec/mms-agent
brew install mms-agent
```

The tap repo only needs the `Formula/` directory. No other structure is required.
Source: [Homebrew Taps docs](https://docs.brew.sh/Taps)

## Formula DSL Skeleton

The `mms-agent.rb` class name must match the file name (capitalized, CamelCase). The full
multi-platform skeleton for four Burrito targets:

```ruby
class MmsAgent < Formula
  desc "MMS Agent - local agent binary for marketmyspec.com"
  homepage "https://marketmyspec.com"
  version "0.1.0"
  license "Proprietary"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/market-my-spec/mms-agent/releases/download/v0.1.0/market_my_spec_agent_macos_m1"
      sha256 "REPLACE_WITH_SHA256_OF_macos_m1_BINARY"
    else
      url "https://github.com/market-my-spec/mms-agent/releases/download/v0.1.0/market_my_spec_agent_macos"
      sha256 "REPLACE_WITH_SHA256_OF_macos_BINARY"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/market-my-spec/mms-agent/releases/download/v0.1.0/market_my_spec_agent_linux_aarch64"
      sha256 "REPLACE_WITH_SHA256_OF_linux_aarch64_BINARY"
    else
      url "https://github.com/market-my-spec/mms-agent/releases/download/v0.1.0/market_my_spec_agent_linux"
      sha256 "REPLACE_WITH_SHA256_OF_linux_BINARY"
    end
  end

  def install
    # The downloaded file is the binary itself (not a tarball).
    # Rename it to the canonical command name and place on PATH.
    bin.install stable.url.split("/").last => "mms-agent"
  end

  test do
    assert_match "mms-agent", shell_output("#{bin}/mms-agent help")
  end
end
```

### Notes on the DSL

- `on_macos` / `on_linux` — selects the right block at install time based on the user's OS.
- `Hardware::CPU.arm?` — true on Apple Silicon (aarch64) and Linux ARM64.
- `url` + `sha256` must be paired; each platform variant needs its own checksum.
- `version` is set at the top level and applies to all platform variants. When you release
  v0.2.0, bump this field and update every `url` + `sha256`.
- `license` — "Proprietary" is a valid SPDX identifier for closed-source software in a
  third-party tap. Homebrew/homebrew-core requires OSS licenses; third-party taps do not.

## Direct (Raw) Binary vs. Tarball

Burrito outputs a single bare executable (not a tarball). The formula above downloads that
file directly via `url`. In `install`, use `stable.url.split("/").last` to get the original
filename and rename it to `mms-agent`.

Alternatively, if CI produces a tarball (e.g., `mms-agent-v0.1.0-macos_m1.tar.gz`):

```ruby
def install
  bin.install "mms-agent"   # name inside the tarball
end
```

Homebrew automatically extracts archives before calling `install`. If the binary is bare
(no tarball), you must rename it yourself as shown above.

## Single-Arch vs. Multi-Arch Branching

For an early release that only ships `macos_m1`:

```ruby
class MmsAgent < Formula
  desc "MMS Agent - local agent binary for marketmyspec.com"
  homepage "https://marketmyspec.com"
  version "0.1.0"
  license "Proprietary"

  url "https://github.com/market-my-spec/mms-agent/releases/download/v0.1.0/market_my_spec_agent_macos_m1"
  sha256 "REPLACE_WITH_SHA256"

  def install
    bin.install "market_my_spec_agent_macos_m1" => "mms-agent"
  end

  test do
    assert_match "mms-agent", shell_output("#{bin}/mms-agent help")
  end
end
```

Start here. Expand to the `on_macos`/`on_linux` block form once all four Burrito targets are
built in CI.

## Updating the Formula on Release

Each new version requires:

1. Bump `version` in the formula.
2. Update `url` strings to point at the new tag.
3. Recompute `sha256` for each platform asset: `shasum -a 256 <binary-file>`.
4. Commit to `homebrew-mms-agent` and tag `v<version>`.

This is automatable via a GitHub Actions step in the release pipeline (see
`github-releases-pipeline.md`).

## References

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Taps](https://docs.brew.sh/Taps)
- [Guide to creating your first Homebrew tap](https://kristoffer.dev/blog/guide-to-creating-your-first-homebrew-tap/)
- [Dynamic url for binary packages (Homebrew discussion)](https://github.com/orgs/Homebrew/discussions/1069)
