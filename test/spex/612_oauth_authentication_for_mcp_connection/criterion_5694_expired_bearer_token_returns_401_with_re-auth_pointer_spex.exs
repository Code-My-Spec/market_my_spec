defmodule MarketMySpecSpex.Story612.Criterion5694Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5694 — Expired bearer token returns 401 with re-auth pointer
  """

  use MarketMySpecSpex.Case

  spex "expired bearer token is rejected with re-auth guidance" do
    scenario "MCP request with an expired bearer token receives a 401 and a re-auth pointer", context do
      given_ "an MCP client holding an expired bearer token", context do
        expired_token = "eyJhbGciOiJub25lIn0.eyJzdWIiOiJ0ZXN0IiwiZXhwIjoxfQ."
        {:ok, Map.put(context, :expired_token, expired_token)}
      end

      when_ "it sends a request to the MCP endpoint with the expired token", context do
        conn =
          context.conn
          |> put_req_header("authorization", "Bearer #{context.expired_token}")
          |> put_req_header("content-type", "application/json")
          |> post("/mcp", ~s({"jsonrpc":"2.0","method":"initialize","id":1,"params":{}}))

        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "the server responds with 401", context do
        assert response(context.conn, 401)
        :ok
      end

      then_ "the WWW-Authenticate header provides a re-auth pointer", context do
        www_auth = get_resp_header(context.conn, "www-authenticate")
        assert www_auth != []
        assert Enum.any?(www_auth, fn v -> v =~ "Bearer" end)
        assert Enum.any?(www_auth, fn v -> v =~ ~r/error=|resource_metadata/ end)
        :ok
      end
    end
  end
end
