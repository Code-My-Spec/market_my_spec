defmodule MarketMySpecSpex.ProblemDiscoveryHelpers do
  @moduledoc """
  Shared helpers for ProblemDiscovery spex (stories 739-743).

  Mirrors `MarketMySpecSpex.RedditHelpers` / `OAuthHelpers`: wraps the
  call under test in `with_openai_cassette/2` / `with_apify_cassette/2`
  / `with_problem_discovery_cassette/2`, which inject ReqCassette's plug
  into `Embeddings.openai_client/0` / `Source.Upwork.apify_client/0`
  via app env for the duration of the call.

  ## Recording new cassettes

      MIX_ENV=test REQ_CASSETTE_MODE=record mix spex test/spex/.../my_spex.exs

  Replay-only by default; the env var or
  `Application.put_env(:req_cassette, :mode, :record)` flips it. After
  recording, commit the resulting JSON files.

  ## Cassette scrubbing
  Authorization headers ARE filtered (api keys never land in cassette
  JSON). Request bodies are NOT scrubbed — review before committing.
  """

  import ReqCassette

  @openai_dir "test/cassettes/openai"
  @apify_dir "test/cassettes/apify"
  @combined_dir "test/cassettes/problem_discovery"

  @doc """
  Combined cassette for tests that hit BOTH OpenAI Embeddings AND Apify
  (i.e., a full Gather → Cluster run). Each side gets its own cassette
  under `test/cassettes/problem_discovery/<name>_{openai,apify}.json`.

  First run records both. Subsequent runs replay — fast and offline.
  """
  @spec with_problem_discovery_cassette(String.t(), (-> any())) :: any()
  def with_problem_discovery_cassette(name, fun) do
    File.mkdir_p!(@combined_dir)
    opts = cassette_opts(@combined_dir)

    with_cassette "#{name}_openai", opts, fn openai_plug ->
      record_apify_cassette(name, opts, openai_plug, fun)
    end
  end

  defp record_apify_cassette(name, opts, openai_plug, fun) do
    with_cassette "#{name}_apify", opts, fn apify_plug ->
      with_combined_plugs(openai_plug, apify_plug, fun)
    end
  end

  defp with_combined_plugs(openai_plug, apify_plug, fun) do
    with_app_env(:openai_req_options, [plug: openai_plug, retry: false], fn ->
      with_app_env(:apify_req_options, [plug: apify_plug, retry: false], fun)
    end)
  end

  @doc "Runs `fun` with a ReqCassette plug installed for OpenAI calls only."
  @spec with_openai_cassette(String.t(), (-> any())) :: any()
  def with_openai_cassette(name, fun) do
    with_cassette name, cassette_opts(@openai_dir), fn plug ->
      with_app_env(:openai_req_options, [plug: plug, retry: false], fun)
    end
  end

  @doc "Runs `fun` with a ReqCassette plug installed for Apify calls only."
  @spec with_apify_cassette(String.t(), (-> any())) :: any()
  def with_apify_cassette(name, fun) do
    with_cassette name, cassette_opts(@apify_dir), fn plug ->
      with_app_env(:apify_req_options, [plug: plug, retry: false], fun)
    end
  end

  defp cassette_opts(dir) do
    [
      cassette_dir: dir,
      mode: cassette_mode(),
      match_requests_on: [:method, :uri, :query, :body],
      filter_request_headers: ["authorization"],
      req_options: [
        connect_options: [transport_opts: tls_transport_opts()]
      ]
    ]
  end

  defp cassette_mode do
    case System.get_env("REQ_CASSETTE_MODE") do
      "record" -> :record
      "bypass" -> :bypass
      "replay" -> :replay
      _ -> Application.get_env(:req_cassette, :mode, :replay)
    end
  end

  defp tls_transport_opts do
    if Code.ensure_loaded?(CAStore) do
      [cacertfile: CAStore.file_path()]
    else
      [cacerts: :public_key.cacerts_get()]
    end
  rescue
    _ -> []
  end

  defp with_app_env(key, value, fun) do
    previous = Application.get_env(:market_my_spec, key, [])
    Application.put_env(:market_my_spec, key, value)

    try do
      fun.()
    after
      if previous == [] do
        Application.delete_env(:market_my_spec, key)
      else
        Application.put_env(:market_my_spec, key, previous)
      end
    end
  end
end
