defmodule MarketMySpecSpex.Story609.Criterion5677Spex do
  @moduledoc """
  Story 609 — Sign Up And Sign In With Email Magic Link
  Criterion 5677 — Returning user signs in with a fresh magic link
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "returning confirmed user signs in via magic link" do
    scenario "confirmed user sees the login form when they open their magic link" do
      given_ "a confirmed user with a fresh magic link token", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they visit the magic link URL", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in/#{context.token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page greets them with their email address", context do
        assert render(context.view) =~ context.user.email
        {:ok, context}
      end

      then_ "the returning-user login form is shown, not a first-time confirmation form", context do
        assert has_element?(context.view, "#login_form")
        refute has_element?(context.view, "#confirmation_form")
        {:ok, context}
      end

      then_ "a log-in button is available to complete sign-in", context do
        html = render(context.view)
        assert html =~ ~r/Keep me logged in on this device|Log me in only this time|Log in/
        {:ok, context}
      end
    end

    scenario "confirmed user is signed in after submitting the magic-link login form" do
      given_ "a confirmed user with a fresh magic link token", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they visit the magic link and submit the login form", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in/#{context.token}")

        form_elem = form(view, "#login_form", %{"user" => %{"token" => context.token}})
        render_submit(form_elem)
        conn = follow_trigger_action(form_elem, context.conn)

        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "they are redirected to the signed-in area of the app", context do
        assert redirected_to(context.conn) == "/"
        {:ok, context}
      end

      then_ "a session token is set confirming they are authenticated", context do
        assert get_session(context.conn, :user_token)
        {:ok, context}
      end
    end
  end
end
