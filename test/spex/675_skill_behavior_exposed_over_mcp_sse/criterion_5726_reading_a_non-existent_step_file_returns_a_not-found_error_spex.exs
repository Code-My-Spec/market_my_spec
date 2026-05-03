defmodule MarketMySpecSpex.Story675.Criterion5726Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5726 — Reading a non-existent step file returns a not-found error
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "reading a non-existent step file returns a not-found error" do
    scenario "agent requesting a missing file receives an error, not an empty body" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the MCP client registers as an OAuth application", context do
        reg_conn =
          post(context.conn, "/oauth/register", %{
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

        {:ok,
         Map.merge(context, %{
           code_verifier: code_verifier,
           code_challenge: code_challenge,
           redirect_uri: "https://localhost:3000/callback"
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
              "state" => "test_state"
            })

        {:ok, view, _html} = live(context.conn, auth_url)
        {:ok, Map.put(context, :auth_view, view)}
      end

      when_ "the user approves the authorization request", context do
        {:error, {:redirect, %{to: redirect_url}}} =
          context.auth_view
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
        {:ok, Map.put(context, :bearer, bearer)}
      end

      when_ "the agent requests a step file that does not exist", context do
        mcp_conn =
          context.conn
          |> put_req_header("authorization", "Bearer #{context.bearer}")
          |> put_req_header("content-type", "application/json")
          |> post(
            "/mcp",
            ~s({"jsonrpc":"2.0","method":"tools/call","id":1,"params":{"name":"read_skill_file","arguments":{"path":"steps/99_nonexistent_step.md"}}})
          )

        {:ok, Map.put(context, :mcp_conn, mcp_conn)}
      end

      then_ "the response is a JSON-RPC error indicating the file was not found", context do
        body = json_response(context.mcp_conn, 200)
        assert body["jsonrpc"] == "2.0"
        assert Map.has_key?(body, "error"), "expected a JSON-RPC error for missing file"
        {:ok, context}
      end

      then_ "the error response does not contain any file content", context do
        body = json_response(context.mcp_conn, 200)
        assert body["jsonrpc"] == "2.0"
        assert is_nil(body["result"]), "expected no result field in an error response"
        {:ok, context}
      end
    end
  end
end
