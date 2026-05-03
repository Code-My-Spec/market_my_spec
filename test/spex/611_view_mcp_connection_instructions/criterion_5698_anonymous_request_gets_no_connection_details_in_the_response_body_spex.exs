defmodule MarketMySpecSpex.Story611.Criterion5698Spex do
  @moduledoc """
  Story 611 — View MCP Connection Instructions
  Criterion 5698 — Anonymous request gets no connection details in the response body
  """

  use MarketMySpecSpex.Case

  spex "MCP connection details are not leaked to unauthenticated requests" do
    scenario "anonymous HTTP GET to /mcp-setup returns a redirect with no connection details", context do
      given_ "an unauthenticated visitor", context do
        {:ok, context}
      end

      when_ "they send a plain HTTP GET to /mcp-setup", context do
        conn = get(context.conn, "/mcp-setup")
        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "the response redirects to the login page", context do
        assert redirected_to(context.conn) == "/users/log-in"
        :ok
      end

      then_ "the response body contains no MCP server URL", context do
        body = response(context.conn, 302)
        # Anchor: confirm we actually got a redirect response
        assert redirected_to(context.conn) == "/users/log-in"
        refute body =~ "/mcp"
        :ok
      end

      then_ "the response body contains no install command", context do
        body = response(context.conn, 302)
        # Anchor: confirm we got a redirect, not an empty page
        assert redirected_to(context.conn) == "/users/log-in"
        refute body =~ "claude mcp add"
        :ok
      end
    end

    scenario "anonymous LiveView request to /mcp-setup is rejected before the page mounts", context do
      given_ "an unauthenticated visitor", context do
        {:ok, context}
      end

      when_ "their browser attempts to mount the MCP setup LiveView", context do
        result = live(context.conn, "/mcp-setup")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the LiveView is rejected — no setup content is delivered", context do
        assert {:error, {:live_redirect, %{to: "/users/log-in"}}} = context.result
        :ok
      end
    end
  end
end
