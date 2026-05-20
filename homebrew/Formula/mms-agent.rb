# mms-agent Homebrew formula.
#
# This file is a TEMPLATE — the canonical formula lives in the tap repo
# (`Code-My-Spec/homebrew-mms-agent`) and is auto-generated on every
# tag push by `.github/workflows/release.yml` (the `update_formula`
# job). Copy this file into the tap repo for the first release, then
# let CI maintain it.
#
# Local testing without the tap repo:
#   1. `MIX_ENV=prod_agent mix release market_my_spec_agent --overwrite`
#   2. `shasum -a 256 burrito_out/market_my_spec_agent_macos_m1`
#   3. Replace REPLACE_ME_<TARGET> below with the computed hashes.
#   4. `brew install --formula ./homebrew/Formula/mms-agent.rb` against
#      a file:// URL or a private GitHub release.
class MmsAgent < Formula
  desc "MMS Agent — local pairing companion for Market My Spec"
  homepage "https://marketmyspec.com"
  version "0.1.0"
  license "Proprietary"

  depends_on :macos

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/Code-My-Spec/market_my_spec/releases/download/v0.1.0/market_my_spec_agent_macos_m1"
      sha256 "REPLACE_ME_MACOS_M1"
    else
      url "https://github.com/Code-My-Spec/market_my_spec/releases/download/v0.1.0/market_my_spec_agent_macos"
      sha256 "REPLACE_ME_MACOS"
    end
  end

  def install
    src = stable.url.split("/").last
    bin.install src => "mms-agent"
  end

  test do
    assert_match "mms-agent", shell_output("#{bin}/mms-agent help")
  end
end
