defmodule MarketMySpecSpex.Story611.Criterion5697Spex do
  @moduledoc """
  Story 611 — View MCP Connection Instructions
  Criterion 5697 — Anonymous visitor is bounced through sign-in to /mcp-setup
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "anonymous visitor redirect flow" do
    scenario "unauthenticated visitor is redirected to the login page" do
      given_ "an unauthenticated visitor", context do
        {:ok, context}
      end

      when_ "they attempt to visit the MCP setup page", context do
        result = live(context.conn, "/mcp-setup")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "they are sent to the login page instead of seeing the setup instructions", context do
        assert {:error, {:live_redirect, %{to: "/users/log-in"}}} = context.result
        {:ok, context}
      end
    end

    scenario "after signing in the visitor is returned to /mcp-setup" do
      given_ "an unauthenticated visitor", context do
        {:ok, context}
      end

      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they try to visit the MCP setup page before signing in", context do
        conn = get(context.conn, "/mcp-setup")
        {:ok, Map.put(context, :conn, conn)}
      end

      when_ "they complete sign-in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "they are returned to the MCP setup page", context do
        assert redirected_to(context.conn) == "/mcp-setup"
        {:ok, context}
      end
    end
  end
end
