defmodule MarketMySpecSpex.Story675.Criterion5725Spex do
  @moduledoc """
  Story 675 — Skill Behavior Exposed Over MCP (SSE)
  Criterion 5725 — Agent reads step 3 file on demand and only step 3 lands in context
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  @skill_root "skills/marketing-strategy"

  spex "agent reads step 3 file on demand and only step 3 content is returned" do
    scenario "connected agent calls read_skill_file for step 3 and receives only that step's content" do
      given_ "a registered user and the canonical step 3 content", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)

        step3_content =
          Application.app_dir(:market_my_spec, @skill_root)
          |> Path.join("steps/03_persona_research.md")
          |> File.read!()

        {:ok, Map.merge(context, %{user: user, token: token, step3_content: step3_content})}
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

      when_ "the agent calls read_skill_file for step 3", context do
        mcp_conn =
          context.conn
          |> put_req_header("authorization", "Bearer #{context.bearer}")
          |> put_req_header("content-type", "application/json")
          |> post(
            "/mcp",
            ~s({"jsonrpc":"2.0","method":"tools/call","id":1,"params":{"name":"read_skill_file","arguments":{"path":"steps/03_persona_research.md"}}})
          )

        {:ok, Map.put(context, :mcp_conn, mcp_conn)}
      end

      then_ "the response contains the step 3 file content", context do
        body = json_response(context.mcp_conn, 200)
        content_text = get_in(body, ["result", "content", Access.at(0), "text"]) || ""
        assert byte_size(content_text) > 0, "expected non-empty step 3 content"
        assert content_text == context.step3_content
        {:ok, context}
      end

      then_ "the response does not include SKILL.md step-list content from other files", context do
        body = json_response(context.mcp_conn, 200)
        content_text = get_in(body, ["result", "content", Access.at(0), "text"]) || ""
        assert content_text =~ ~r/persona|research/i
        refute content_text =~ "steps/01_current_state.md"
        {:ok, context}
      end
    end
  end
end
