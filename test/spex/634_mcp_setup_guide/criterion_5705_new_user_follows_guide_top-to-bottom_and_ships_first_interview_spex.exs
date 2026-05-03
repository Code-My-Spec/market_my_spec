defmodule MarketMySpecSpex.Story634.Criterion5705Spex do
  @moduledoc """
  Story 634 — MCP Setup Guide
  Criterion 5705 — New user follows guide top-to-bottom and ships first interview
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "new user follows guide top-to-bottom and ships first interview" do
    scenario "signed-in user sees all three setup steps in sequence" do
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
        {:ok, view, html} = live(context.conn, "/mcp-setup")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the install step is present", context do
        assert has_element?(context.view, "[data-test='install-step']")
        {:ok, context}
      end

      then_ "the OAuth sign-in step is present", context do
        assert has_element?(context.view, "[data-test='oauth-step']")
        {:ok, context}
      end

      then_ "the first interview step is present", context do
        assert has_element?(context.view, "[data-test='interview-step']")
        {:ok, context}
      end

      then_ "the install command is present in the guide", context do
        assert has_element?(context.view, "[data-test='install-command']")
        assert context.html =~ "claude mcp add"
        {:ok, context}
      end
    end
  end
end
