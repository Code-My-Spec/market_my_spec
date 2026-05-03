defmodule MarketMySpecSpex.Story675.Criterion5715Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5715 — MCP session initializes over SSE and serves resources
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "MCP session initializes over SSE and serves resources" do
    scenario "authenticated MCP client connects to the SSE endpoint and receives a valid session" do
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

      when_ "the client connects to the MCP SSE endpoint", context do
        sse_conn =
          context.conn
          |> put_req_header("authorization", "Bearer #{context.bearer}")
          |> put_req_header("accept", "text/event-stream")
          |> get("/mcp")

        {:ok, Map.put(context, :sse_conn, sse_conn)}
      end

      then_ "the SSE endpoint returns a 200 status", context do
        assert context.sse_conn.status == 200
        {:ok, context}
      end

      then_ "the response content-type is text/event-stream", context do
        assert context.sse_conn.status == 200
        [content_type | _] = get_resp_header(context.sse_conn, "content-type")
        assert content_type =~ "text/event-stream"
        {:ok, context}
      end
    end
  end
end
