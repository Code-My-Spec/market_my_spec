defmodule MarketMySpecSpex.Story674.Criterion5732Spex do
  @moduledoc """
  Story 674 — Start A Marketing Strategy Interview
  Criterion 5732 — Slash command invocation without bearer fails clearly
  """

  use MarketMySpecSpex.Case

  spex "slash command invocation without bearer fails clearly" do
    scenario "MCP request without a bearer token is rejected with a clear 401", context do
      given_ "no bearer token is present", context do
        :ok
      end

      when_ "the client sends an MCP request without a bearer token", context do
        mcp_conn =
          context.conn
          |> put_req_header("content-type", "application/json")
          |> post("/mcp", ~s({"jsonrpc":"2.0","method":"tools/call","id":1,"params":{"name":"invoke_skill","arguments":{"skill_name":"marketing-strategy"}}}))

        {:ok, Map.put(context, :mcp_conn, mcp_conn)}
      end

      then_ "the MCP endpoint rejects the request with a 401 status", context do
        assert context.mcp_conn.status == 401
        :ok
      end

      then_ "the response includes a WWW-Authenticate header", context do
        assert context.mcp_conn.status == 401
        [www_auth | _] = get_resp_header(context.mcp_conn, "www-authenticate")
        assert www_auth =~ ~r/Bearer/i
        :ok
      end
    end
  end
end
