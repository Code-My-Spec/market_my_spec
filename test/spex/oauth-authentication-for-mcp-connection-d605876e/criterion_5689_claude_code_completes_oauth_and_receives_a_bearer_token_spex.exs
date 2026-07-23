defmodule MarketMySpecSpex.Story612.Criterion5689Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5689 — Claude Code completes OAuth and receives a bearer token
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "full OAuth PKCE flow produces a bearer token" do
    scenario "Claude Code registers, the user approves, and the client receives an access token" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the MCP client registers", context do
        reg_conn = post(context.conn, "/oauth/register", %{
          "redirect_uris" => ["https://localhost:3000/callback"],
          "client_name" => "Claude Code",
          "token_endpoint_auth_method" => "none"
        })
        %{"client_id" => client_id, "client_secret" => client_secret} = json_response(reg_conn, 201)
        {:ok, Map.merge(context, %{client_id: client_id, client_secret: client_secret})}
      end

      when_ "PKCE values are prepared", context do
        code_verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
        code_challenge = :crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)
        {:ok, Map.merge(context, %{
          code_verifier: code_verifier,
          code_challenge: code_challenge,
          redirect_uri: "https://localhost:3000/callback",
          state: "test_state"
        })}
      end

      when_ "the user visits the authorization page", context do
        auth_url =
          "/oauth/authorize?" <>
            URI.encode_query(%{
              "client_id" => context.client_id,
              "redirect_uri" => context.redirect_uri,
              "response_type" => "code",
              "code_challenge" => context.code_challenge,
              "code_challenge_method" => "S256",
              "state" => context.state
            })

        {:ok, view, _html} = live(context.conn, auth_url)
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user approves the authorization request", context do
        # Phoenix.LiveView.redirect(external: url) produces {:error, {:redirect, %{to: url, status: 302}}}
        # in tests (the LiveView test framework normalizes external redirects to the :to key).
        {:error, {:redirect, %{to: redirect_url}}} =
          context.view
          |> element("[data-test='approve-button']")
          |> render_click()

        %{"code" => auth_code} =
          redirect_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        {:ok, Map.put(context, :auth_code, auth_code)}
      end

      when_ "the client exchanges the code for a token", context do
        token_conn =
          post(context.conn, "/oauth/token", %{
            "grant_type" => "authorization_code",
            "code" => context.auth_code,
            "redirect_uri" => context.redirect_uri,
            "client_id" => context.client_id,
            "client_secret" => context.client_secret,
            "code_verifier" => context.code_verifier
          })

        body = json_response(token_conn, 200)
        {:ok, Map.put(context, :token_response, body)}
      end

      then_ "the response contains an access token", context do
        assert Map.has_key?(context.token_response, "access_token")
        refute context.token_response["access_token"] =~ ~r/^\s*$/
        {:ok, context}
      end

      then_ "the token type is Bearer", context do
        assert context.token_response["token_type"] =~ ~r/bearer/i
        {:ok, context}
      end
    end
  end
end
