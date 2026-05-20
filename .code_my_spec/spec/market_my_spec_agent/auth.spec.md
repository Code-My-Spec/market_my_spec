# MarketMySpecAgent.Auth

Disk persistence for paired-agent credentials. Reads and writes `~/.mms-agent/auth.json` (file mode 0600, parent directory mode 0700). The credential map has four required string keys: `"agent_id"` (UUID), `"token"` (opaque long-lived token issued by the server's `/agents/pair` endpoint), `"server_url"` (e.g. `"https://app.marketmyspec.com"`), and `"paired_at"` (ISO-8601 UTC string). `read/0` returns `{:ok, map}` on success; `{:error, :missing}` when the file does not exist; `{:error, :unreadable}` on any other filesystem error; and `{:error, :invalid_json}` when the file exists but cannot be decoded as a JSON object. `write/1` accepts any `map`, encodes it with Jason, creates the parent directory with `File.mkdir_p!/1` if absent, writes atomically (overwriting any prior file), then `chmod`s the file to 0600 and the directory to 0700. `path/0` and `dir/0` return the absolute string paths derived from `System.user_home!/0`. `Auth` itself holds no state — it is a pure I/O module called from `Auth.Store` on startup and on each successful pairing.

## Type

module

## Dependencies

- MarketMySpecAgent
