defmodule MarketMySpecSpex.Story634.Criterion5707Spex do
  @moduledoc """
  Story 634 — MCP Setup Guide
  Criterion 5707 — User hits port conflict and recovers via troubleshooting block
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "port conflict troubleshooting block is present" do
    scenario "user sees a port conflict troubleshooting block in the setup guide", context do
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

      then_ "a port conflict troubleshooting block is present", context do
        assert has_element?(context.view, "[data-test='port-conflict-troubleshooting']")
        :ok
      end

      then_ "the port conflict block contains recovery instructions", context do
        assert has_element?(context.view, "[data-test='port-conflict-troubleshooting']")
        block_html = context.view |> element("[data-test='port-conflict-troubleshooting']") |> render()
        assert block_html =~ ~r/port/i
        refute block_html =~ ~r/^\s*$/
        :ok
      end
    end
  end
end
