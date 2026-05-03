defmodule MarketMySpecSpex.Story611.Criterion5695Spex do
  @moduledoc """
  Story 611 — View MCP Connection Instructions
  Criterion 5695 — Signed-in user lands on /mcp-setup with everything they need
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "MCP setup page for authenticated user" do
    scenario "signed-in user sees the server URL on the setup page", context do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "they visit the MCP setup page", context do
        {:ok, view, html} = live(context.conn, "/mcp-setup")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the server URL is shown so they know where to point Claude Code", context do
        assert has_element?(context.view, "[data-test='server-url']")
        assert render(context.view) =~ "/mcp"
        :ok
      end
    end

    scenario "signed-in user sees the install command on the setup page", context do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "they visit the MCP setup page", context do
        {:ok, view, _html} = live(context.conn, "/mcp-setup")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a ready-to-run install command is shown", context do
        assert has_element?(context.view, "[data-test='install-command']")
        assert render(context.view) =~ "claude mcp add"
        :ok
      end
    end

    scenario "signed-in user sees the OAuth flow explained on the setup page", context do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "they visit the MCP setup page", context do
        {:ok, view, _html} = live(context.conn, "/mcp-setup")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "instructions about the OAuth authorization step are present", context do
        assert has_element?(context.view, "[data-test='oauth-instructions']")
        :ok
      end
    end
  end
end
