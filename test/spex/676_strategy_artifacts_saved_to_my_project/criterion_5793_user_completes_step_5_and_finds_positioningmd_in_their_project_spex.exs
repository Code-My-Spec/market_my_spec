defmodule MarketMySpecSpex.Story676.Criterion5793Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Project
  Criterion 5793 — User completes step 5 and finds positioning.md in their project
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "step 5 instructs the agent to write positioning.md to the local marketing/ directory" do
    scenario "the agent reading step 5 over MCP receives instructions to write marketing/05_positioning.md locally", context do
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

      when_ "the agent reads step 5 via read_skill_file", context do
        mcp_conn =
          context.conn
          |> put_req_header("authorization", "Bearer #{context.bearer}")
          |> put_req_header("content-type", "application/json")
          |> post(
            "/mcp",
            ~s({"jsonrpc":"2.0","method":"tools/call","id":1,"params":{"name":"read_skill_file","arguments":{"path":"steps/05_positioning.md"}}})
          )

        {:ok, Map.put(context, :mcp_conn, mcp_conn)}
      end

      then_ "the response contains step 5 content with the local positioning.md write instruction", context do
        body = json_response(context.mcp_conn, 200)
        content_text = get_in(body, ["result", "content", Access.at(0), "text"]) || ""

        assert byte_size(content_text) > 0, "expected non-empty step 5 content"
        assert content_text =~ ~r/[Ww]rite `marketing\/05_positioning\.md`/,
               "expected write instruction for marketing/05_positioning.md in step 5 content"

        :ok
      end

      then_ "the response references the local marketing/ directory, not a server URL", context do
        body = json_response(context.mcp_conn, 200)
        content_text = get_in(body, ["result", "content", Access.at(0), "text"]) || ""

        assert content_text =~ "marketing/05_positioning.md",
               "expected canonical marketing/05_positioning.md path"

        refute content_text =~ ~r/https?:\/\/[^\s]+positioning/,
               "expected no server URL pointing to positioning content"

        :ok
      end
    end
  end
end
