defmodule MarketMySpecSpex.Story612.Criterion5703Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5703 — MCP client discovers auth server from MCP endpoint URL
  """

  use MarketMySpecSpex.Case

  spex "MCP endpoint auth server discovery" do
    scenario "unauthenticated request to the MCP endpoint returns a 401 with an auth server pointer" do
      given_ "an MCP client without a bearer token", context do
        {:ok, context}
      end

      when_ "it sends a request to the MCP endpoint without authorization", context do
        conn =
          context.conn
          |> put_req_header("content-type", "application/json")
          |> post("/mcp", ~s({"jsonrpc":"2.0","method":"initialize","id":1,"params":{}}))

        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "the server responds with 401", context do
        assert response(context.conn, 401)
        {:ok, context}
      end

      then_ "the WWW-Authenticate header points toward the authorization server", context do
        www_auth = get_resp_header(context.conn, "www-authenticate")
        assert www_auth != []
        assert Enum.any?(www_auth, fn v -> v =~ "Bearer" end)
        {:ok, context}
      end
    end
  end
end
