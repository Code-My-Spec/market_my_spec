defmodule MarketMySpecSpex.Story612.Criterion5702Spex do
  @moduledoc """
  Story 612 — OAuth Authentication For MCP Connection
  Criterion 5702 — Revoke request with invalid token format is rejected
  """

  use MarketMySpecSpex.Case

  spex "token revocation validation" do
    scenario "revocation request with a syntactically invalid token is rejected", context do
      given_ "an MCP client with a malformed token", context do
        {:ok, context}
      end

      when_ "it sends a revocation request with the invalid token", context do
        conn = post(context.conn, "/oauth/revoke", %{
          "token" => "not a valid token !! @@ ##"
        })
        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "the server rejects the request with 400", context do
        assert response(context.conn, 400)
        :ok
      end

      then_ "the error body contains an invalid_request error code", context do
        body = json_response(context.conn, 400)
        assert body["error"] == "invalid_request"
        :ok
      end
    end
  end
end
