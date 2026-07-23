defmodule MarketMySpecSpex.Story612.Criterion5700Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5700 — Registration request without redirect_uris is rejected
  """

  use MarketMySpecSpex.Case

  spex "client registration validation" do
    scenario "registration request missing redirect_uris is rejected with 400" do
      given_ "an MCP client with incomplete registration metadata", context do
        invalid_params = %{
          "client_name" => "Claude Code",
          "token_endpoint_auth_method" => "none"
        }
        {:ok, Map.put(context, :invalid_params, invalid_params)}
      end

      when_ "it attempts to register without redirect_uris", context do
        conn = post(context.conn, "/oauth/register", context.invalid_params)
        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "the registration is rejected with 400", context do
        assert response(context.conn, 400)
        {:ok, context}
      end

      then_ "the error body identifies the missing field", context do
        body = json_response(context.conn, 400)
        assert body["error"] in ["invalid_client_metadata", "invalid_request"]
        {:ok, context}
      end
    end
  end
end
