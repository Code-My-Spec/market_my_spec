defmodule MarketMySpecSpex.Story611.Criterion5696Spex do
  @moduledoc """
  Story 611 — View MCP Connection Instructions
  Criterion 5696 — Page missing server URL or install command is rejected

  This spec is the quality gate: it asserts that the rendered page always
  exposes both a non-empty server URL and a non-empty install command.
  If either element is absent or blank, the spec fails and the page is
  considered unfit to ship.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "MCP setup page quality gate" do
    scenario "the server URL element is present and non-empty" do
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

      then_ "a server-url element is rendered", context do
        assert has_element?(context.view, "[data-test='server-url']")
        {:ok, context}
      end

      then_ "the server-url element is not blank", context do
        server_url_text =
          context.view
          |> element("[data-test='server-url']")
          |> render()

        assert has_element?(context.view, "[data-test='server-url']")
        refute server_url_text =~ ~r/^\s*$/
        {:ok, context}
      end
    end

    scenario "the install command element is present and non-empty" do
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

      then_ "an install-command element is rendered", context do
        assert has_element?(context.view, "[data-test='install-command']")
        {:ok, context}
      end

      then_ "the install-command element is not blank", context do
        install_cmd_text =
          context.view
          |> element("[data-test='install-command']")
          |> render()

        assert has_element?(context.view, "[data-test='install-command']")
        refute install_cmd_text =~ ~r/^\s*$/
        {:ok, context}
      end
    end
  end
end
