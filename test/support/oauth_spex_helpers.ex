defmodule MarketMySpecSpex.OAuthHelpers do
  @moduledoc """
  Shared helpers for Story 672/673 BDD specs that exercise the public OAuth
  sign-in callback at `/auth/:provider/callback` (UserOAuthController).

  Provides:
  - `build_google_cassette!/2` — loads
    `test/cassettes/oauth/google_login_shape.json` (a real Google OIDC
    recording with id_token + JWKS keys scrubbed to placeholders) and
    injects a fresh per-test id_token + matching JWK so signature
    verification passes. Failure-path scenarios pass
    `:token_response_overrides` opts to merge arbitrary fields into the
    token endpoint response.
  - `build_github_cassette!/3` — loads
    `test/cassettes/oauth/github_login_shape.json` (a real recording of
    GitHub's `/user` and `/user/emails` responses with PII scrubbed to
    placeholders) and replaces the response bodies with the supplied
    per-test user_json + emails_json.
  - `with_assent_plug/2` — temporarily injects ReqCassette's plug into
    the Assent HTTP adapter for the duration of a single call block.
  - `do_google_callback/3` / `do_github_callback/3` — drive the full
    `GET /auth/:provider/callback` request with the correct session and
    OAuthStateStore state for MMS's `UserOAuthController.callback/2`.

  ## Session model (different from code_my_spec)

  CMS stashes provider, session_params, and flow in three session keys.
  MMS's UserOAuthController only stashes the provider in
  `:sign_in_oauth_provider`; the OAuth `session_params` (the `state`
  parameter and any nonce) live in `MarketMySpec.Integrations.OAuthStateStore`,
  keyed by the state token, with a 5-minute TTL. These helpers seed both.

  ## Re-recording the shape cassettes

  The shape cassettes were originally captured in code_my_spec. To re-record:

      # In code_my_spec:
      rm test/cassettes/oauth/google_login_shape.json
      TEST_GOOGLE_REFRESH_TOKEN=<rt> mix test --only record_google_login_shape

      rm test/cassettes/oauth/github_login_shape.json
      TEST_GITHUB_ACCESS_TOKEN=<at> mix test --only record_github_login_shape

  Then `cp` the resulting JSONs into market_my_spec's
  `test/cassettes/oauth/`. The recordings are provider-shape recordings
  with credentials and PII scrubbed; they are not bound to either project.
  """

  use Boundary, deps: [MarketMySpec]

  import Phoenix.ConnTest
  import Plug.Conn
  import ReqCassette

  alias MarketMySpec.Integrations.OAuthStateStore

  @cassette_dir "test/cassettes/oauth"
  @endpoint MarketMySpecWeb.Endpoint

  @issuer "https://accounts.google.com"
  @token_endpoint "https://oauth2.googleapis.com/token"
  @jwks_uri "https://www.googleapis.com/oauth2/v3/certs"
  @kid "test-google-key-1"

  @shape_cassette_path "test/cassettes/oauth/google_login_shape.json"

  @doc """
  Builds a Google OIDC cassette by loading the real-shape recording and
  injecting a fresh per-test id_token + matching JWK so signature
  verification passes.

  ## Options

  - `:token_response_overrides` — map merged into the token endpoint
    response body. Use to drive failure-path scenarios (e.g. empty
    access_token) without abandoning the real-shape recording.
  """
  def build_google_cassette!(cassette_name, user_claims, opts \\ []) do
    overrides = Keyword.get(opts, :token_response_overrides, %{})
    {pem, n, e} = generate_rsa_keypair()
    client_id = Application.fetch_env!(:market_my_spec, :google_client_id)
    id_token = sign_id_token(pem, user_claims, client_id)
    jwk = public_jwk(n, e)

    shape =
      @shape_cassette_path
      |> File.read!()
      |> Jason.decode!()

    cassette =
      shape
      |> merge_token_response(overrides)
      |> inject_id_token(id_token)
      |> inject_jwks([jwk])

    File.mkdir_p!(@cassette_dir)
    path = Path.join(@cassette_dir, cassette_name <> ".json")
    File.write!(path, Jason.encode!(cassette, pretty: true))
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    :ok
  end

  defp merge_token_response(cassette, overrides) when overrides == %{}, do: cassette

  defp merge_token_response(cassette, overrides) do
    update_in(cassette, ["interactions"], fn interactions ->
      Enum.map(interactions, fn interaction ->
        if get_in(interaction, ["request", "uri"]) == @token_endpoint do
          update_in(interaction, ["response", "body_json"], &Map.merge(&1, overrides))
        else
          interaction
        end
      end)
    end)
  end

  defp inject_id_token(cassette, id_token) do
    update_in(cassette, ["interactions"], fn interactions ->
      Enum.map(interactions, fn interaction ->
        if get_in(interaction, ["request", "uri"]) == @token_endpoint do
          put_in(interaction, ["response", "body_json", "id_token"], id_token)
        else
          interaction
        end
      end)
    end)
  end

  defp inject_jwks(cassette, jwks) do
    update_in(cassette, ["interactions"], fn interactions ->
      Enum.map(interactions, fn interaction ->
        if get_in(interaction, ["request", "uri"]) == @jwks_uri do
          put_in(interaction, ["response", "body_json", "keys"], jwks)
        else
          interaction
        end
      end)
    end)
  end

  @github_shape_cassette_path "test/cassettes/oauth/github_login_shape.json"
  @github_user_url "https://api.github.com/user"
  @github_user_emails_url "https://api.github.com/user/emails"

  @doc """
  Builds a GitHub OAuth cassette by loading the real-shape recording and
  replacing the /user and /user/emails response bodies with `user_json`
  and `emails_json`.
  """
  def build_github_cassette!(cassette_name, user_json, emails_json) do
    shape =
      @github_shape_cassette_path
      |> File.read!()
      |> Jason.decode!()

    cassette =
      shape
      |> inject_response_body(@github_user_url, user_json)
      |> inject_response_body(@github_user_emails_url, emails_json)

    File.mkdir_p!(@cassette_dir)
    path = Path.join(@cassette_dir, cassette_name <> ".json")
    File.write!(path, Jason.encode!(cassette, pretty: true))
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    :ok
  end

  defp inject_response_body(cassette, target_uri, body) do
    update_in(cassette, ["interactions"], fn interactions ->
      Enum.map(interactions, fn interaction ->
        if get_in(interaction, ["request", "uri"]) == target_uri do
          put_in(interaction, ["response", "body_json"], body)
        else
          interaction
        end
      end)
    end)
  end

  @doc """
  Temporarily replaces the Assent HTTP adapter with the given ReqCassette plug
  for the duration of `fun/0`.
  """
  def with_assent_plug(plug, fun) do
    previous = Application.get_env(:assent, :http_adapter)
    Application.put_env(:assent, :http_adapter, {Assent.HTTPAdapter.Req, [plug: plug]})

    try do
      fun.()
    after
      case previous do
        nil -> Application.delete_env(:assent, :http_adapter)
        adapter -> Application.put_env(:assent, :http_adapter, adapter)
      end
    end
  end

  @doc """
  Drives the Google OAuth callback through `GET /auth/google/callback` using
  the named cassette. Seeds the session and `OAuthStateStore` exactly as
  `UserOAuthController.request/2` would have, then issues the callback.
  Returns the resulting conn.
  """
  def do_google_callback(base_conn, cassette_name, state \\ "google-state") do
    OAuthStateStore.store(state, %{state: state})

    with_cassette cassette_name, cassette_opts(), fn plug ->
      with_assent_plug(plug, fn ->
        base_conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_session(:sign_in_oauth_provider, :google)
        |> get("/auth/google/callback", %{"code" => "google-replay-code", "state" => state})
      end)
    end
  end

  @doc """
  Drives the GitHub OAuth callback through `GET /auth/github/callback` using
  the named cassette. Seeds the session and `OAuthStateStore` exactly as
  `UserOAuthController.request/2` would have, then issues the callback.
  Returns the resulting conn.
  """
  def do_github_callback(base_conn, cassette_name, state \\ "github-state") do
    OAuthStateStore.store(state, %{state: state})

    with_cassette cassette_name, cassette_opts(), fn plug ->
      with_assent_plug(plug, fn ->
        base_conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_session(:sign_in_oauth_provider, :github)
        |> get("/auth/github/callback", %{"code" => "github-replay-code", "state" => state})
      end)
    end
  end

  @doc """
  Returns cassette options for replay mode.
  """
  def cassette_opts do
    [
      cassette_dir: @cassette_dir,
      mode: :replay,
      match_requests_on: [:method, :uri],
      filter_request_headers: ["authorization", "cookie"],
      filter_response_headers: ["set-cookie"]
    ]
  end

  # -- Private: RSA / JWT / cassette generation --

  defp generate_rsa_keypair do
    rsa_private = :public_key.generate_key({:rsa, 2048, 65_537})
    {:RSAPrivateKey, _v, n, e, _d, _p, _q, _e1, _e2, _c, _other} = rsa_private

    pem =
      :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, rsa_private)])

    {pem, n, e}
  end

  defp sign_id_token(pem, claims, client_id) do
    now = :os.system_time(:second)

    id_token_claims =
      claims
      |> Map.put("iss", @issuer)
      |> Map.put("aud", client_id)
      |> Map.put("azp", client_id)
      |> Map.put("iat", now)
      |> Map.put("exp", now + 3600)

    {:ok, jwt} =
      Assent.JWTAdapter.AssentJWT.sign(
        id_token_claims,
        "RS256",
        pem,
        private_key_id: @kid,
        json_library: Jason
      )

    jwt
  end

  defp public_jwk(n, e) do
    %{
      "kty" => "RSA",
      "alg" => "RS256",
      "use" => "sig",
      "kid" => @kid,
      "n" => Base.url_encode64(:binary.encode_unsigned(n), padding: false),
      "e" => Base.url_encode64(:binary.encode_unsigned(e), padding: false)
    }
  end
end
