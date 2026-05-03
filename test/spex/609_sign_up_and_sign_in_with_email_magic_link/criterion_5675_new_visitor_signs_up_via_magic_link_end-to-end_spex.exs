defmodule MarketMySpecSpex.Story609.Criterion5675Spex do
  @moduledoc """
  Story 609 — Sign Up And Sign In With Email Magic Link
  Criterion 5675 — New visitor signs up via magic link end-to-end
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "new visitor signs up via magic link" do
    scenario "registration sends a magic link email and redirects to the login page", context do
      given_ "a new visitor on the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they submit a new email address", context do
        email = "newvisitor#{System.unique_integer()}@example.com"

        {:ok, _view, html} =
          context.view
          |> form("#registration_form", user: %{email: email})
          |> render_submit()
          |> follow_redirect(context.conn, "/users/log-in")

        {:ok, Map.merge(context, %{email: email, redirect_html: html})}
      end

      then_ "they see a message about checking their email", context do
        assert context.redirect_html =~
                 ~r/An email was sent to .*, please access it to confirm your account/
        :ok
      end

      then_ "they are on the login page where they can wait for the link to arrive", context do
        assert context.redirect_html =~ "Log in"
        :ok
      end
    end

    scenario "new unconfirmed user sees the confirmation form when opening their magic link", context do
      given_ "a new unconfirmed user with a fresh magic link token", context do
        user = Fixtures.unconfirmed_user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they visit the magic link URL", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in/#{context.token}")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page greets them with their email address", context do
        assert render(context.view) =~ context.user.email
        :ok
      end

      then_ "the first-time confirmation form is shown, not a returning-user login form", context do
        assert has_element?(context.view, "#confirmation_form")
        refute has_element?(context.view, "#login_form")
        :ok
      end

      then_ "a confirm-and-stay-logged-in button is visible", context do
        assert has_element?(context.view, "button", "Confirm and stay logged in")
        :ok
      end
    end

    scenario "new user completes sign-up by submitting the confirmation form", context do
      given_ "a new unconfirmed user with a fresh magic link token", context do
        user = Fixtures.unconfirmed_user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "they submit the confirmation form", context do
        {:ok, view, _html} = live(context.conn, "/users/log-in/#{context.token}")

        form_elem = form(view, "#confirmation_form", %{"user" => %{"token" => context.token}})
        render_submit(form_elem)
        conn = follow_trigger_action(form_elem, context.conn)

        {:ok, Map.put(context, :conn, conn)}
      end

      then_ "they are signed in and redirected to the app", context do
        assert redirected_to(context.conn) == "/"
        :ok
      end

      then_ "a success flash confirms their account was set up", context do
        assert Phoenix.Flash.get(context.conn.assigns.flash, :info) =~
                 "User confirmed successfully"
        :ok
      end

      then_ "a session token is established for the new account", context do
        assert get_session(context.conn, :user_token)
        :ok
      end
    end
  end
end
