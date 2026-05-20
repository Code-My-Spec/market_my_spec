# Integration with Server

How the Homebrew formula, the binary's startup flow, and the server-side endpoints
interlock. What the server should expose to support version checking and pairing.

## The Install-to-Pair Journey

```
brew tap market-my-spec/mms-agent
brew install mms-agent
  -> Homebrew downloads signed binary, clears quarantine, places on PATH

mms-agent pair
  -> binary opens browser to https://marketmyspec.com/agents/pair?state=...&port=...&name=...
  -> user logs in, clicks Approve
  -> server POSTs token + agent_id to local loopback listener (port from &port=)
  -> binary writes ~/.mms-agent/auth.json (mode 0600)
  -> binary prints "Paired." and exits

mms-agent status
  -> binary reads ~/.mms-agent/auth.json
  -> calls GET /api/agent/status with Bearer token
  -> prints connectivity + version check output
```

The pair flow is already implemented (Story 731). The version-check endpoint is the
missing piece needed to support the phone-home update pattern.

## Required Server Endpoints

### GET /api/agent/version (new, lightweight)

Returns the latest available binary version and the minimum still-supported version.
Used by the binary on startup to decide whether to print an upgrade notice.

```
GET /api/agent/version
Accept: application/json

200 OK
{
  "latest": "0.2.0",
  "min_supported": "0.1.0",
  "download_url": "https://github.com/market-my-spec/mms-agent/releases/latest"
}
```

This endpoint does not require authentication. It is purely informational.
Cache-Control header recommended: `max-age=86400` (24 hours) so CDN/browser caches work.

Server implementation: a single Phoenix controller action that returns a hardcoded or
config-driven version string. No database needed. Update the config value when you publish
a new Homebrew formula.

### GET /api/agent/status (already planned)

Authenticated. Returns agent health from the server's perspective:

```
GET /api/agent/status
Authorization: Bearer <token>

200 OK
{
  "agent_id": "...",
  "user_id": "...",
  "paired_at": "2026-05-19T12:00:00Z",
  "channel_connected": false
}
```

Used by `mms-agent status` subcommand. Already in scope for Story 732.

## Version Check Implementation in the Binary

In the `mms-agent status` (and optionally `help`) subcommand handler:

```elixir
defmodule MarketMySpecAgent.CLI.VersionCheck do
  @current_version Mix.Project.config()[:version]
  # Stamped at compile time so it survives inside the Burrito binary.
  @version @current_version

  @cache_path Path.expand("~/.mms-agent/version_check.json")
  @cache_ttl_seconds 86_400  # 24 hours

  def maybe_warn do
    with {:ok, %{"latest" => latest}} <- fetch_or_cached(),
         :gt <- Version.compare(latest, @version) do
      IO.puts("Notice: mms-agent v#{latest} is available. Run: brew upgrade mms-agent")
    end
  end

  defp fetch_or_cached do
    case File.read(@cache_path) do
      {:ok, content} ->
        data = Jason.decode!(content)
        fetched_at = DateTime.from_iso8601(data["fetched_at"]) |> elem(1)
        age = DateTime.diff(DateTime.utc_now(), fetched_at)
        if age < @cache_ttl_seconds, do: {:ok, data}, else: fetch_and_cache()
      _ ->
        fetch_and_cache()
    end
  end

  defp fetch_and_cache do
    server_url = MarketMySpecAgent.Config.server_url()
    case Req.get("#{server_url}/api/agent/version") do
      {:ok, %{status: 200, body: body}} ->
        data = Map.put(body, "fetched_at", DateTime.to_iso8601(DateTime.utc_now()))
        File.write!(@cache_path, Jason.encode!(data))
        {:ok, body}
      _ ->
        {:error, :unavailable}
    end
  end
end
```

`@version` is set at compile time. Inside a Burrito binary, `Mix.Project.config()[:version]`
is evaluated during compilation and embedded as a module attribute, so it is available at
runtime without a Mix environment.

## Signed Release Manifest (Optional)

For stronger trust (relevant if self-update is added later), publish a signed manifest
alongside the GitHub Release:

```json
{
  "version": "0.2.0",
  "released_at": "2026-06-01T00:00:00Z",
  "assets": {
    "macos_m1":      { "sha256": "abc...", "url": "https://github.com/.../market_my_spec_agent_macos_m1" },
    "macos":         { "sha256": "def...", "url": "https://github.com/.../market_my_spec_agent_macos" },
    "linux":         { "sha256": "ghi...", "url": "https://github.com/.../market_my_spec_agent_linux" },
    "linux_aarch64": { "sha256": "jkl...", "url": "https://github.com/.../market_my_spec_agent_linux_aarch64" }
  }
}
```

Sign with `gpg --detach-sign manifest.json`. Not needed for the Homebrew-only distribution
path (Homebrew verifies SHA256 itself), but would be needed if you implement an in-binary
self-update path later.

## What Homebrew Does vs. What the Binary Does

| Concern | Who handles it |
|---|---|
| Download binary | Homebrew |
| Verify SHA256 | Homebrew |
| Clear macOS quarantine | Homebrew (post-install) |
| Place binary on PATH | Homebrew (`bin.install`) |
| Pair with server (OAuth dance) | Binary (`mms-agent pair`) |
| Store credentials | Binary (`~/.mms-agent/auth.json`) |
| Check for newer version | Binary (phone-home on `status`) |
| Update to newer version | User (`brew upgrade mms-agent`) |
| Notify user to update | Binary (prints notice) |
