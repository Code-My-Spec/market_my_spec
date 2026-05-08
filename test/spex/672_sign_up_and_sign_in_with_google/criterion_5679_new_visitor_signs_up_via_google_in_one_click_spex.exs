defmodule MarketMySpecSpex.Story672.Criterion5679Spex do
  @moduledoc """
  Story 672 — Sign Up And Sign In With Google
  Criterion 5679 — New visitor signs up via Google in one click

  The Google sign-in entry point must be present on BOTH the login page
  (returning users) and the registration page (new visitors). The story is
  "Sign Up And Sign In", so a new visitor landing on `/users/register`
  needs to see the one-click option without first navigating to log-in.

  The full callback flow is exercised through ReqCassette-replayed Google
  OIDC interactions (see `test/support/oauth_spex_helpers.ex`): a fresh
  RSA keypair is generated per test, an `id_token` is signed with the
  test claims, and the JWKS endpoint serves the matching public key — so
  Assent's signature verification passes against an offline cassette.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Users
  alias MarketMySpecSpex.OAuthHelpers

  spex "new visitor signs up via Google in one click" do
    scenario "anonymous visitor sees Google sign-in on the login page" do
      given_ "an anonymous visitor", context do
        {:ok, context}
      end

      when_ "they visit the login page", context do
        {:ok, view, html} = live(context.conn, "/users/log-in")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a Google sign-in option is present on the login page", context do
        assert has_element?(context.view, "[data-test='google-sign-in']")
        {:ok, context}
      end

      then_ "the Google button links to the public sign-in route", context do
        assert has_element?(context.view, "a[href='/auth/google'][data-test='google-sign-in']")
        {:ok, context}
      end
    end

    scenario "anonymous visitor sees Google sign-in on the registration page" do
      given_ "an anonymous visitor", context do
        {:ok, context}
      end

      when_ "they visit the registration page", context do
        {:ok, view, html} = live(context.conn, "/users/register")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a Google sign-in option is present on the registration page", context do
        assert has_element?(context.view, "[data-test='google-sign-in']"),
               "expected the Google sign-in button on /users/register so new visitors " <>
                 "can sign up in one click without navigating to /users/log-in first"

        {:ok, context}
      end

      then_ "the Google button links to the public sign-in route", context do
        assert has_element?(context.view, "a[href='/auth/google'][data-test='google-sign-in']")
        {:ok, context}
      end
    end

    scenario "callback creates a new user, logs them in, and redirects them home" do
      given_ "a brand-new email address Google will return on callback", context do
        unique = System.unique_integer([:positive])
        email = "new-visitor-#{unique}@example.com"

        user_claims = %{
          "sub" => "google-sub-5679-#{unique}",
          "email" => email,
          "email_verified" => true,
          "name" => "New Visitor",
          "given_name" => "New",
          "family_name" => "Visitor"
        }

        cassette = "google_5679_#{unique}"
        OAuthHelpers.build_google_cassette!(cassette, user_claims)

        # Pre-condition: no MMS user with this email yet.
        refute Users.get_user_by_email(email),
               "expected no pre-existing user for #{email} before the OAuth flow"

        {:ok,
         Map.merge(context, %{email: email, user_claims: user_claims, cassette: cassette})}
      end

      when_ "the Google OAuth callback completes via cassette replay", context do
        callback_conn =
          OAuthHelpers.do_google_callback(
            context.conn,
            context.cassette,
            "google-state-5679-#{System.unique_integer([:positive])}"
          )

        {:ok, Map.put(context, :callback_conn, callback_conn)}
      end

      then_ "the user is redirected to the signed-in landing path", context do
        assert redirected_to(context.callback_conn, 302) == "/",
               "expected post-OAuth redirect to / (signed_in_path for fresh sessions)"

        {:ok, context}
      end

      then_ "the session carries a user_token, indicating the visitor is logged in", context do
        assert Plug.Conn.get_session(context.callback_conn, :user_token),
               "expected :user_token to be set in session after a successful OAuth callback"

        {:ok, context}
      end

      then_ "the success flash confirms the sign-in", context do
        info_flash = Phoenix.Flash.get(context.callback_conn.assigns.flash, :info)
        assert info_flash =~ ~r/signed in/i,
               "expected 'Signed in successfully' info flash; got: #{inspect(info_flash)}"

        {:ok, context}
      end

      then_ "a user record was created with the email Google returned", context do
        user = Users.get_user_by_email(context.email)

        assert user,
               "expected the OAuth callback to create a user with email #{context.email}"

        assert user.email == context.email
        {:ok, context}
      end
    end
  end
end
