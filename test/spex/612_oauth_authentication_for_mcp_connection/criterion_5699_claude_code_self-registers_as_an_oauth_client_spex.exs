defmodule MarketMySpecSpex.Story612.Criterion5699Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5699 — Claude Code self-registers as an OAuth client
  """

  use MarketMySpecSpex.Case

  spex "dynamic OAuth client registration" do
    scenario "MCP client registers with valid metadata and receives a client_id" do
      given_ "an MCP client with valid registration metadata", context do
        registration_params = %{
          "redirect_uris" => ["https://localhost:3000/callback"],
          "client_name" => "Claude Code",
          "token_endpoint_auth_method" => "none",
          "grant_types" => ["authorization_code"],
          "response_types" => ["code"]
        }
        {:ok, Map.put(context, :registration_params, registration_params)}
      end

      when_ "it registers with the authorization server", context do
        conn = post(context.conn, "/oauth/register", context.registration_params)
        body = json_response(conn, 201)
        {:ok, Map.merge(context, %{conn: conn, registration: body})}
      end

      then_ "the response includes a client_id", context do
        assert Map.has_key?(context.registration, "client_id")
        refute context.registration["client_id"] =~ ~r/^\s*$/
        {:ok, context}
      end

      then_ "the response echoes back the redirect_uris", context do
        assert context.registration["redirect_uris"] == ["https://localhost:3000/callback"]
        {:ok, context}
      end
    end
  end
end
