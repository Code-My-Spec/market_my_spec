# Signing and Gatekeeper

What it takes to make the MMS Agent binary install cleanly on macOS without security
warnings. Covers Developer ID signing, notarization, stapling, and CI integration.

## The Problem

A Burrito-built BEAM executable is a foreign binary from macOS's perspective. When a user
downloads it (including via `brew install`), Gatekeeper quarantines it. Without a valid
Developer ID signature and Apple notarization, the user sees:

> "market_my_spec_agent_macos_m1" cannot be opened because Apple cannot verify it is free
> of malware.

Clicking "Open Anyway" works once per user, but it's friction. For CLI tools distributed
via Homebrew, the expected UX is that it "just works" out of the box.

Note: Homebrew itself applies an ad-hoc signature (`codesign --sign -`) to downloaded
binaries when running on Apple Silicon, which prevents the "damaged and can't be opened"
error, but it does NOT substitute for a real Developer ID signature + notarization for the
full Gatekeeper clearance.

## What You Need

| Item | Where to get | Cost |
|---|---|---|
| Apple Developer Program membership | developer.apple.com/programs | $99/year |
| Developer ID Application certificate | Developer Portal > Certificates | Included |
| App-specific password for Apple ID | appleid.apple.com > Security | Free |
| macOS machine (or CI runner) with Xcode | GitHub macos-14 runner | Included in GH Actions |

The certificate must be a "Developer ID Application" type (not a Mac App Store distribution
certificate). It is used to sign CLI binaries distributed outside the App Store.

## Step-by-Step: Sign and Notarize

These steps run in the GitHub Actions release pipeline after the Burrito build.

### 1. Import certificate into the runner's keychain

```bash
# Secrets needed in the repo:
# APPLE_DEVELOPER_CERTIFICATE_P12_BASE64  — base64-encoded .p12 export
# APPLE_DEVELOPER_CERTIFICATE_PASSWORD    — .p12 password
# APPLE_ID                                — developer Apple ID email
# APPLE_APP_SPECIFIC_PASSWORD             — app-specific password from appleid.apple.com
# APPLE_TEAM_ID                           — 10-char team ID from developer.apple.com

echo "$APPLE_DEVELOPER_CERTIFICATE_P12_BASE64" | base64 --decode > /tmp/cert.p12

security create-keychain -p "" build.keychain
security default-keychain -s build.keychain
security unlock-keychain -p "" build.keychain
security import /tmp/cert.p12 -k build.keychain \
  -P "$APPLE_DEVELOPER_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain
```

### 2. Code-sign the binary

```bash
CERT_NAME="Developer ID Application: Your Name ($APPLE_TEAM_ID)"
BINARY=burrito_out/market_my_spec_agent_macos_m1

codesign \
  --sign "$CERT_NAME" \
  --timestamp \
  --options runtime \
  --verbose \
  "$BINARY"

# Verify
codesign --verify --verbose=4 "$BINARY"
```

`--timestamp` embeds a secure timestamp (required for notarization).
`--options runtime` enables the hardened runtime (required for notarization).

### 3. Zip for notarization

Standalone binaries cannot be directly submitted to Apple's notarization service. They
must be wrapped in a zip or DMG first. The zip content only needs to contain the binary
(no installer structure required).

```bash
zip -j /tmp/mms-agent-notarize.zip "$BINARY"
```

### 4. Submit for notarization

```bash
xcrun notarytool submit /tmp/mms-agent-notarize.zip \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait \
  --output-format json
```

`--wait` blocks until Apple's service finishes (typically 1-5 minutes). On success, the
exit code is 0 and the JSON output contains `"status": "Accepted"`.

### 5. Stapling

Stapling attaches the notarization ticket to the binary so Gatekeeper can verify it
offline (no network check on user's machine). Stapling only works for DMG files and .app
bundles — not for standalone executables or zip archives.

**For bare CLI binaries distributed as-is (no DMG), stapling is not possible.**

This means: users need a network connection the first time they run the binary, so
Gatekeeper can verify with Apple's OCSP/notarization service. In practice this is always
available and the check is instantaneous. It is not a meaningful limitation for a
developer-audience CLI tool.

If you want stapling, wrap the binary in a DMG:

```bash
hdiutil create -volname "MMS Agent" -srcfolder "$BINARY" \
  -ov -format UDZO mms-agent.dmg
xcrun notarytool submit mms-agent.dmg --wait ...
xcrun stapler staple mms-agent.dmg
```

Then distribute the DMG, not the raw binary. This adds significant complexity and is
not worth it for a Homebrew-distributed CLI. Skip stapling for now.

## GitHub Actions Integration

Add a job step in the release workflow after the Burrito build step, before uploading
the asset:

```yaml
- name: Sign and notarize (macOS only)
  if: runner.os == 'macOS'
  env:
    APPLE_DEVELOPER_CERTIFICATE_P12_BASE64: ${{ secrets.APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 }}
    APPLE_DEVELOPER_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_DEVELOPER_CERTIFICATE_PASSWORD }}
    APPLE_ID: ${{ secrets.APPLE_ID }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
    APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
  run: |
    # Import cert
    echo "$APPLE_DEVELOPER_CERTIFICATE_P12_BASE64" | base64 --decode > /tmp/cert.p12
    security create-keychain -p "" build.keychain
    security default-keychain -s build.keychain
    security unlock-keychain -p "" build.keychain
    security import /tmp/cert.p12 -k build.keychain \
      -P "$APPLE_DEVELOPER_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple: -s -k "" build.keychain

    # Sign
    BINARY=burrito_out/${{ matrix.output_name }}
    codesign --sign "Developer ID Application: Market My Spec ($APPLE_TEAM_ID)" \
      --timestamp --options runtime --verbose "$BINARY"

    # Notarize
    zip -j /tmp/notarize.zip "$BINARY"
    xcrun notarytool submit /tmp/notarize.zip \
      --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" --wait
```

## The Ad-Hoc Alternative (Early Users, Bootstrap Phase)

If you are not yet a paying Apple Developer Program member ($99/year), you can ship
unsigned binaries with documented instructions for early users:

```bash
# One-time quarantine removal after brew install
xattr -d com.apple.quarantine $(which mms-agent)
```

Or document: System Settings > Privacy & Security > scroll to "market_my_spec_agent..."
> "Open Anyway".

This is fine for the first 10-20 technical early adopters (developers who understand the
risk) but will block broader distribution. Budget the $99/year into launch costs.

## Linux Notes

Linux has no equivalent of Gatekeeper. The binary runs as-is after `chmod +x`. No signing
required for Linux distribution via Homebrew on Linux (Homebrew/homebrew on Linux does
not check signatures). If distributing via `.deb`/`.rpm` later, those package formats
have their own GPG signing mechanisms.

## References

- [The ultimate guide to signing CLIs for macOS](https://tuist.dev/blog/2024/12/31/signing-macos-clis)
- [Apple: Signing Mac Software with Developer ID](https://developer.apple.com/developer-id/)
- [Apple: Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [A rough guide to notarizing CLI apps for macOS (2024)](https://www.randomerrata.com/articles/2024/notarize/)
- [dennisbabkin: How to code-sign and notarize macOS binaries](https://dennisbabkin.com/blog/?t=how-to-get-certificate-code-sign-notarize-macos-binaries-outside-apple-app-store)
