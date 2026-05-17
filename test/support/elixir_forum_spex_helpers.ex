defmodule MarketMySpecSpex.ElixirForumHelpers do
  @moduledoc """
  Shared helpers for story-714 ElixirForum (Discourse) and cross-source
  spex.

  Pure ReqCassette record-and-replay — NO cassette authoring in code.
  On first run with `mode: :record`, the cassette captures real HTTP
  responses from `elixirforum.com` and (for mixed cassettes) `reddit.com`.
  Subsequent runs replay from disk with no network.

  ## Wrappers

  - `with_elixirforum_cassette/2` — injects ReqCassette's plug into
    `Engagements.HTTP.elixirforum_client/0` via `:elixirforum_req_options`
    app env. Use for ElixirForum-only spex.

  - `with_mixed_cassette/2` — injects the SAME plug into both
    `:reddit_req_options` and `:elixirforum_req_options` so a single
    orchestrator call that fans out to both sources is served from one
    cassette. ReqCassette matches on URI so each request finds its
    corresponding recorded interaction.

  ## Recording

  Cassettes default to `:replay` mode. To record (or re-record) a
  cassette, set the mode via app env before running the spex:

      MIX_ENV=test mix run -e 'Application.put_env(:req_cassette, :mode, :record)' \\
        && rm test/cassettes/elixirforum/<name>.json \\
        && mix spex test/spex/714_*/criterion_<n>_*.exs

  Or set the env globally for a single run:

      MIX_ENV=test REQ_CASSETTE_MODE=record mix spex test/spex/714_*/

  In `:record` mode ReqCassette captures any new interactions on disk
  and replays existing ones. To force a fresh recording, delete the
  cassette file first.

  ## Failure scenarios

  Real recordings can't easily capture 5xx / 429 / network failures.
  Spex that exercise failure paths should either:

  1. Record the real failure (e.g., trigger a Discourse rate limit on
     purpose during a record-mode run), or
  2. Use a different test pattern that doesn't involve ReqCassette for
     failure injection (e.g., temporarily point the HTTP client at a
     local stub that returns the desired status).

  ## Boundary

  Test-support only. The Boundary `deps: [MarketMySpec]` allows reaching
  into the production Engagements.HTTP modules for client config.
  """

  use Boundary, deps: [MarketMySpec]

  import ReqCassette

  @cassette_dir "test/cassettes/elixirforum"

  @doc """
  Runs `fun` with ReqCassette's plug injected into
  `Engagements.HTTP.elixirforum_client/0`.

  Cassette: `test/cassettes/elixirforum/<name>.json`. Matched on
  method + uri + query. Mode is read from `:req_cassette` app env
  (default `:replay`).
  """
  @spec with_elixirforum_cassette(String.t(), (-> any())) :: any()
  def with_elixirforum_cassette(cassette_name, fun) do
    with_cassette cassette_name, cassette_opts(), fn plug ->
      with_elixirforum_plug(plug, fun)
    end
  end

  @doc """
  Runs `fun` with ReqCassette's plug injected into BOTH the Reddit and
  ElixirForum HTTP clients, so a single orchestrator call that fans out
  to both sources is served from one cassette.

  Use for story-714 cross-source spex (criterion 6283 / 6284 / 6285
  / 6287 / 6393 / 6394 / 6395 / 6396 / 6397) where one
  `search_engagements` call hits Reddit and ElixirForum venues in the
  same envelope.
  """
  @spec with_mixed_cassette(String.t(), (-> any())) :: any()
  def with_mixed_cassette(cassette_name, fun) do
    with_cassette cassette_name, cassette_opts(), fn plug ->
      with_both_plugs(plug, fun)
    end
  end

  defp cassette_mode do
    case System.get_env("REQ_CASSETTE_MODE") do
      "record" -> :record
      "bypass" -> :bypass
      "replay" -> :replay
      _ -> Application.get_env(:req_cassette, :mode, :replay)
    end
  end

  defp cassette_opts do
    [
      cassette_dir: @cassette_dir,
      mode: cassette_mode(),
      # Discourse paths embed the category id; Reddit query strings carry
      # the keyword/limit. Match on all three so cross-source interactions
      # route correctly inside one cassette.
      match_requests_on: [:method, :uri, :query],
      filter_request_headers: ["authorization", "cookie"],
      # ReqCassette in :record mode builds a fresh Req without the
      # caller's base config — forward the TLS opts so HTTPS works.
      req_options: [
        connect_options: [transport_opts: tls_transport_opts()]
      ]
    ]
  end

  defp tls_transport_opts do
    cond do
      Code.ensure_loaded?(CAStore) -> [cacertfile: CAStore.file_path()]
      true -> [cacerts: :public_key.cacerts_get()]
    end
  rescue
    _ -> []
  end

  defp with_elixirforum_plug(plug, fun) do
    previous = Application.get_env(:market_my_spec, :elixirforum_req_options, [])
    Application.put_env(:market_my_spec, :elixirforum_req_options, plug: plug)

    try do
      fun.()
    after
      restore_env(:elixirforum_req_options, previous)
    end
  end

  defp with_both_plugs(plug, fun) do
    previous_reddit = Application.get_env(:market_my_spec, :reddit_req_options, [])
    previous_forum = Application.get_env(:market_my_spec, :elixirforum_req_options, [])

    Application.put_env(:market_my_spec, :reddit_req_options, plug: plug)
    Application.put_env(:market_my_spec, :elixirforum_req_options, plug: plug)

    try do
      fun.()
    after
      restore_env(:reddit_req_options, previous_reddit)
      restore_env(:elixirforum_req_options, previous_forum)
    end
  end

  defp restore_env(key, previous) do
    if previous == [] do
      Application.delete_env(:market_my_spec, key)
    else
      Application.put_env(:market_my_spec, key, previous)
    end
  end
end
