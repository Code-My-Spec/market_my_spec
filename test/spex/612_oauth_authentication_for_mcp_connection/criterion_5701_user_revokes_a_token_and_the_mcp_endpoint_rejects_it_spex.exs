defmodule MarketMySpecSpex.Story612.Criterion5701Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5701 — User revokes a token and the MCP endpoint rejects it
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "revoked token is rejected by the MCP endpoint" do
    scenario "a bearer token stops working after the user revokes it" do
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
        {:error, {:redirect, %{to: redirect_url}}} =
          context.view
          |> element("[data-test='approve-button']")
          |> render_click()

        %{"code" => auth_code} =
          redirect_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

        {:ok, Map.put(context, :auth_code, auth_code)}
      end

      when_ "the client exchanges the code for a bearer token", context do
        token_conn =
          post(context.conn, "/oauth/token", %{
            "grant_type" => "authorization_code",
            "code" => context.auth_code,
            "redirect_uri" => context.redirect_uri,
            "client_id" => context.client_id,
            "code_verifier" => context.code_verifier
          })

        %{"access_token" => bearer} = json_response(token_conn, 200)
        {:ok, Map.put(context, :bearer_token, bearer)}
      end

      when_ "the user revokes the token", context do
        post(context.conn, "/oauth/revoke", %{"token" => context.bearer_token})
        {:ok, context}
      end

      when_ "the MCP client tries to use the revoked token", context do
        mcp_conn =
          context.conn
          |> put_req_header("authorization", "Bearer #{context.bearer_token}")
          |> put_req_header("content-type", "application/json")
          |> post("/mcp", ~s({"jsonrpc":"2.0","method":"initialize","id":1,"params":{}}))

        {:ok, Map.put(context, :mcp_conn, mcp_conn)}
      end

      then_ "the MCP endpoint rejects the revoked token with 401", context do
        assert response(context.mcp_conn, 401)
        {:ok, context}
      end
    end
  end
end
