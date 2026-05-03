defmodule MarketMySpecSpex.Story609.Criterion5678Spex do
  @moduledoc """
  Story 609 — Sign Up And Sign In With Email Magic Link
  Criterion 5678 — Expired or consumed magic link surfaces a recoverable error
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "magic link expiry and consumption" do
    scenario "visiting an invalid magic link redirects to login with an error message" do
      given_ "a visitor with an invalid magic link URL", context do
        {:ok, context}
      end

      when_ "they attempt to open the invalid magic link", context do
        result = live(context.conn, "/users/log-in/totallyinvalidtoken")
        {:error, {:live_redirect, %{to: path}}} = result
        {:ok, _view, login_html} = live(context.conn, path)
        {:ok, Map.merge(context, %{result: result, login_html: login_html})}
      end

      then_ "they are redirected to the login page rather than crashing", context do
        assert {:error, {:live_redirect, %{to: "/users/log-in"}}} = context.result
        {:ok, context}
      end

      then_ "the login page explains the link is invalid so they can request a new one", context do
        assert context.login_html =~ "Magic link is invalid or it has expired"
        assert context.login_html =~ "Log in"
        {:ok, context}
      end
    end

    scenario "a consumed magic link is rejected and the user can request a fresh one" do
      given_ "a confirmed user with a magic link token", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they sign in once with the magic link to consume it", context do
        post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, context}
      end

      when_ "they try the same magic link URL a second time", context do
        result = live(context.conn, "/users/log-in/#{context.token}")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "they are redirected to the login page to request a fresh link", context do
        assert {:error, {:live_redirect, %{to: "/users/log-in"}}} = context.result
        {:ok, context}
      end
    end
  end
end
