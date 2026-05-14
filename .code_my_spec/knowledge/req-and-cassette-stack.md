# Req and ReqCassette Stack — Knowledge Reference

As of 2026-05-14.

## Req — Current State

- **Latest stable version:** 0.5.17 (per https://hex.pm/packages/req)
- **Hex package:** `{:req, "~> 0.5"}` — already in `mix.exs`
- **Maintenance status:** Actively maintained by Wojtek Mach; releases are frequent and the project is considered the primary modern HTTP client for Elixir, superceding HTTPoison for new code
- **Built on:** Finch (not Hackney); Finch is already a transitive dependency

Req's architecture is built around composable steps. Each request and response passes through a pipeline of steps registered at `Req.new/1` time or inline. Steps can read and modify the request struct before it's sent, and the response struct after it returns.

## Recommended Middleware Stack for Reddit/Discourse

### Auth Header Attachment

Req's built-in `:auth` option handles bearer tokens:

```elixir
Req.new(base_url: "https://oauth.reddit.com")
|> Req.Request.put_new_header("user-agent", "market_my_spec/0.1 by johns10davenport")
|> Req.merge(auth: {:bearer, token})
```

For Discourse User API Key (non-standard header), use a custom step:

```elixir
defmodule MarketMySpec.Engagements.DiscoursePlug do
  def attach(req, key, client_id) do
    Req.Request.prepend_request_steps(req, discourse_auth: fn req ->
      req
      |> Req.Request.put_header("user-api-key", key)
      |> Req.Request.put_header("user-api-client-id", client_id)
    end)
  end
end
```

### Token Refresh for Reddit

Reddit script apps re-authenticate via password grant on expiry (no refresh token flow needed). Implement a simple GenServer (e.g., `Engagements.Reddit.TokenStore`) that holds the current token and its expiry. Before each request, check if `DateTime.compare(expires_at, DateTime.utc_now()) == :lt` and fetch a new token if so. Alternatively, handle a 401 response in a response step:

```elixir
Req.Request.prepend_response_steps(req, handle_expired_token: fn {req, resp} ->
  if resp.status == 401 do
    new_token = Reddit.Auth.fetch_token()
    {Req.merge(req, auth: {:bearer, new_token.access_token}), resp}
    # Note: the retry step will re-execute the request
  else
    {req, resp}
  end
end)
```

### Retry and Rate-Limit Honoring

Req's built-in `:retry` step handles transient failures. Configure it to honor Reddit's `X-Ratelimit-Reset` header on 429:

```elixir
Req.new(
  retry: :safe_transient,
  max_retries: 3,
  retry_delay: fn resp ->
    case Req.Response.get_header(resp, "x-ratelimit-reset") do
      [reset_in] -> String.to_integer(reset_in) * 1000
      _ -> :timer.seconds(1)
    end
  end
)
```

For Discourse 429 responses (which may include `Retry-After`):

```elixir
retry_delay: fn resp ->
  case Req.Response.get_header(resp, "retry-after") do
    [wait] -> String.to_integer(wait) * 1000
    _ -> :timer.seconds(2)
  end
end
```

### JSON Decode

Req decodes JSON responses automatically when the `Content-Type` is `application/json`. No additional configuration needed. The decoded body is available as a map in `response.body`.

### Recommended Req base client factory

```elixir
defmodule MarketMySpec.Engagements.HTTP do
  def reddit_client(token) do
    Req.new(
      base_url: "https://oauth.reddit.com",
      headers: [{"user-agent", "market_my_spec/0.1 by johns10davenport"}],
      auth: {:bearer, token},
      retry: :safe_transient,
      max_retries: 3,
      retry_delay: &reddit_retry_delay/1
    )
  end

  def discourse_client(key, client_id) do
    Req.new(base_url: "https://elixirforum.com")
    |> Req.Request.prepend_request_steps(discourse_auth: fn req ->
      req
      |> Req.Request.put_header("user-api-key", key)
      |> Req.Request.put_header("user-api-client-id", client_id)
    end)
    |> Req.merge(retry: :safe_transient, max_retries: 3)
  end

  defp reddit_retry_delay(resp) do
    case Req.Response.get_header(resp, "x-ratelimit-reset") do
      [v] -> String.to_integer(v) * 1000
      _ -> 1_000
    end
  end
end
```

## ReqCassette — Current State

- **Latest stable version:** 0.6.0 (per https://hex.pm/packages/req_cassette)
- **Hex package:** `{:req_cassette, "~> 0.6.0", only: :test}` — already in `mix.exs`
- **Maintained by:** lostbean; actively maintained, migration guides exist between major versions
- **GitHub:** https://github.com/lostbean/req_cassette

ReqCassette stores cassettes as pretty-printed JSON files with native JSON objects (not escaped strings). This makes cassettes human-readable and diff-friendly in version control.

### Fixture Format

```json
{
  "version": "1.0",
  "interactions": [
    {
      "request": {
        "method": "GET",
        "uri": "https://oauth.reddit.com/r/elixir/search.json",
        "query_string": "q=codemyspec&restrict_sr=1&sort=new",
        "headers": {"authorization": ["Bearer <filtered>"]},
        "body_type": "text",
        "body": ""
      },
      "response": {
        "status": 200,
        "headers": {"content-type": ["application/json"]},
        "body_type": "json",
        "body_json": { "data": { "children": [] } }
      },
      "recorded_at": "2026-05-14T12:00:00Z"
    }
  ]
}
```

Body types: `json` (stored as native JSON), `text` (plain string), `blob` (base64-encoded binary).

### Recording Modes

| Mode | Behavior |
|---|---|
| `:record` (default) | Records when cassette does not exist; replays when it does |
| `:replay` | Replay-only; errors if no cassette exists. Use in CI |
| `:bypass` | Always makes live calls; ignores cassettes. Debug only |

Set `:replay` in CI by wrapping in a config check, or set globally in `test.exs` if cassettes are always expected to exist.

### API Usage Pattern

```elixir
use ReqCassette

test "searches r/elixir for engagement opportunities" do
  with_cassette "reddit_search_elixir", [mode: :record] do
    # pass the cassette plug to the Req client
    client = Reddit.client_with_cassette(cassette)
    result = Reddit.search(client, subreddit: "elixir", q: "codemyspec")
    assert length(result.posts) > 0
  end
end
```

ReqCassette integrates via `Req.Test` and Phoenix's Plug adapter, making it safe for async (`async: true`) test execution — unlike ExVCR which uses global process state.

### Sensitive Data Filtering

Configure in `test.exs` or in the `with_cassette` options:

```elixir
config :req_cassette,
  cassette_dir: "test/cassettes",
  filter_request_headers: ["authorization", "user-api-key", "user-api-client-id"]
```

Strip auth headers before recording to avoid committing credentials.

## ReqCassette vs. ExVCR

| Concern | ReqCassette | ExVCR |
|---|---|---|
| HTTP client | Req only | HTTPoison, hackney, others |
| Concurrency | Async-safe (Req.Test adapter) | Global mocking (not async-safe) |
| Cassette format | Pretty-printed native JSON | JSON with escaped strings |
| Maintenance | Active | Maintained but lower velocity |
| CI mode | `:replay` enforces no live calls | `:passthrough` / `:record` modes |

## Migration Boundary

**Do not migrate existing ExVCR cassettes.** The PowAssent OAuth integrations (Reddit OAuth sign-in via HTTPoison/Assent) already have ExVCR cassettes. These work and should stay as-is; the existing `exvcr.md` ADR remains in force for that code.

**All new code in the Engagements context uses Req + ReqCassette.** The `Engagements.Reddit` and `Engagements.Discourse` modules use Req; their tests use `with_cassette`.

The two recording systems do not conflict: ExVCR intercepts HTTPoison calls via a global mock; ReqCassette intercepts Req calls via Req.Test plug injection. They operate on different HTTP clients and different test infrastructure.

If HTTPoison is ever removed from the project (after PowAssent is migrated to Assent + Req), ExVCR can be removed at that point.

## Test Recipe for `mix spex` Runs

1. Record cassettes once by running tests with real credentials and `mode: :record` (locally, with `.env` loaded).
2. Commit the cassette files to `test/cassettes/` with auth headers filtered.
3. In CI (and `mix spex`), cassettes replay deterministically with `mode: :replay`.
4. When the real API changes, delete the relevant cassette file and re-record.

Set default mode in `config/test.exs`:

```elixir
config :req_cassette, mode: :replay
```

Override per-test when recording:

```elixir
with_cassette "my_cassette", mode: :record do ... end
```

## Sources

- Req hex page: https://hex.pm/packages/req
- Req docs: https://hexdocs.pm/req/Req.html
- ReqCassette GitHub: https://github.com/lostbean/req_cassette
- ReqCassette hex page: https://hex.pm/packages/req_cassette
- ReqCassette ElixirForum announcement: https://elixirforum.com/t/reqcassette-vcr-style-testing-for-req-with-async-support/72869
