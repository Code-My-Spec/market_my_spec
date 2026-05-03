defmodule MarketMySpecSpex.Story634.Criterion5708Spex do
  @moduledoc """
  Story 634 — MCP Setup Guide
  Criterion 5708 — Page missing one of the three required troubleshooting blocks is rejected

  Quality gate: the guide must ship with three troubleshooting blocks covering
  port conflicts, OAuth failures, and MCP connection issues. Missing any one fails.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "three required troubleshooting blocks quality gate" do
    scenario "the deployed guide contains all three required troubleshooting blocks" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "they visit the MCP setup guide", context do
        {:ok, view, _html} = live(context.conn, "/mcp-setup")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the port conflict troubleshooting block is present", context do
        assert has_element?(context.view, "[data-test='port-conflict-troubleshooting']")
        {:ok, context}
      end

      then_ "the OAuth troubleshooting block is present", context do
        assert has_element?(context.view, "[data-test='oauth-troubleshooting']")
        {:ok, context}
      end

      then_ "the MCP connection troubleshooting block is present", context do
        assert has_element?(context.view, "[data-test='mcp-connection-troubleshooting']")
        {:ok, context}
      end
    end
  end
end
