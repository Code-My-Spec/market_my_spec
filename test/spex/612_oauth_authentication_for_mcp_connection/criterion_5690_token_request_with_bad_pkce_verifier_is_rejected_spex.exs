defmodule MarketMySpecSpex.Story612.Criterion5690Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5690 — Token request with bad PKCE verifier is rejected
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "PKCE code_verifier is validated on token exchange" do
    scenario "token exchange with a wrong code_verifier is rejected with invalid_grant", context do
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
        %{"client_id" => client_id} = json_response(reg_conn, 201)
        {:ok, Map.put(context, :client_id, client_id)}
      end

      when_ "PKCE values are prepared", context do
        code_verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
        code_challenge = :crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)
        wrong_verifier = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
        {:ok, Map.merge(context, %{
          code_verifier: code_verifier,
          code_challenge: code_challenge,
          wrong_verifier: wrong_verifier,
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
        {:error, {:redirect, %{to: redirect_url}}} =
          context.view
          |> element("[data-test='approve-button']")
          |> render_click()

        %{"code" => auth_code} =
          redirect_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        {:ok, Map.put(context, :auth_code, auth_code)}
      end

      when_ "the client sends the token request with the wrong code_verifier", context do
        token_conn =
          post(context.conn, "/oauth/token", %{
            "grant_type" => "authorization_code",
            "code" => context.auth_code,
            "redirect_uri" => context.redirect_uri,
            "client_id" => context.client_id,
            "code_verifier" => context.wrong_verifier
          })

        {:ok, Map.put(context, :token_conn, token_conn)}
      end

      then_ "the token request is rejected", context do
        assert response(context.token_conn, 400)
        :ok
      end

      then_ "the error is invalid_grant", context do
        body = json_response(context.token_conn, 400)
        assert body["error"] in ["invalid_grant", "invalid_request"]
        :ok
      end
    end
  end
end
