defmodule MarketMySpecSpex.Story676.Criterion5747Spex do
  @moduledoc """
  Story 676 — Strategy Artifacts Saved To My Project
  Criterion 5747 — Tool surface contains only the skill + auth tools, no content sinks
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  @allowed_tool_names ["invoke_skill", "read_skill_file"]

  @forbidden_tool_names [
    "save_artifact",
    "write_marketing_file",
    "save_marketing_file",
    "store_artifact",
    "upload_artifact",
    "create_artifact"
  ]

  spex "tools/list response exposes only the skill tools, no content sinks" do
    scenario "MCP client listing tools sees invoke_skill and read_skill_file but no write/save tools", context do
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

      when_ "the agent calls tools/list over MCP", context do
        mcp_conn =
          context.conn
          |> put_req_header("authorization", "Bearer #{context.bearer}")
          |> put_req_header("content-type", "application/json")
          |> post(
            "/mcp",
            ~s({"jsonrpc":"2.0","method":"tools/list","id":1,"params":{}})
          )

        {:ok, Map.put(context, :mcp_conn, mcp_conn)}
      end

      then_ "the response includes the skill tools", context do
        body = json_response(context.mcp_conn, 200)
        tools = get_in(body, ["result", "tools"]) || []
        tool_names = Enum.map(tools, fn tool -> tool["name"] end)

        assert "invoke_skill" in tool_names,
               "expected invoke_skill in tools list, got: #{inspect(tool_names)}"

        assert "read_skill_file" in tool_names,
               "expected read_skill_file in tools list, got: #{inspect(tool_names)}"

        :ok
      end

      then_ "the response contains no content-sink tools", context do
        body = json_response(context.mcp_conn, 200)
        tools = get_in(body, ["result", "tools"]) || []
        tool_names = Enum.map(tools, fn tool -> tool["name"] end)

        assert Enum.any?(@allowed_tool_names, fn allowed -> allowed in tool_names end),
               "anchor: expected allowed tool names to be present, got: #{inspect(tool_names)}"

        Enum.each(@forbidden_tool_names, fn forbidden ->
          refute forbidden in tool_names,
                 "Expected #{forbidden} to be absent from tools/list, got: #{inspect(tool_names)}"
        end)

        :ok
      end

      then_ "no listed tool declares a content parameter", context do
        body = json_response(context.mcp_conn, 200)
        tools = get_in(body, ["result", "tools"]) || []

        assert length(tools) > 0, "expected at least one tool in tools/list response"

        Enum.each(tools, fn tool ->
          properties = get_in(tool, ["inputSchema", "properties"]) || %{}

          assert is_map(properties),
                 "anchor: expected properties for tool #{tool["name"]} to be a map, got: #{inspect(properties)}"

          refute Map.has_key?(properties, "content"),
                 "Expected no content parameter in tool #{tool["name"]}, got properties: #{inspect(Map.keys(properties))}"
        end)

        :ok
      end
    end
  end
end
