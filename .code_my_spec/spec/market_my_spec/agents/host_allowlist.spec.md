# MarketMySpec.Agents.HostAllowlist

Pre-dispatch host validation so the agent never executes arbitrary HTTP. allowed?/1 (url) returns true only for hosts in the configured allowlist (default: reddit.com, oauth.reddit.com — subdomains permitted). allowed_hosts/0 reads the config at runtime so deploys can adjust without code. Dispatcher calls this before broadcasting; rejected URLs return {:error, :host_not_allowed}.

## Type

module
