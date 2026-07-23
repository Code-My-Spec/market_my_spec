defmodule MarketMySpecSpex.Story673.Criterion5685Spex do
  @moduledoc """
  Story 673 — Sign Up And Sign In With GitHub
  Criterion 5685 — Developer signs up via GitHub in one click

  The GitHub sign-in entry point must be present on BOTH the login page
  (returning users) and the registration page (new visitors). The story is
  "Sign Up And Sign In", so a new visitor landing on `/users/register`
  needs to see the one-click option without first navigating to log-in.

  The full callback flow is exercised through ReqCassette-replayed GitHub
  interactions (see `test/support/oauth_spex_helpers.ex`): the recorded
  `/user` and `/user/emails` responses are populated with per-test data,
  so Assent's GitHub strategy returns the test identity offline.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Users
  alias MarketMySpecSpex.OAuthHelpers

  spex "developer signs up via GitHub in one click" do
    scenario "anonymous visitor sees GitHub sign-in on the login page and is redirected to GitHub" do
      given_ "an anonymous visitor", context do
        {:ok, context}
      end

      when_ "they visit the login page", context do
        {:ok, view, html} = live(context.conn, "/users/log-in")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a GitHub sign-in option is present on the login page", context do
        assert has_element?(context.view, "[data-test='github-sign-in']")
        {:ok, context}
      end

      when_ "they initiate the GitHub OAuth flow", context do
        # /auth/github is the public sign-up/sign-in route (no authentication required).
        # GitHub uses Assent.Strategy.OAuth2.Base which constructs the redirect URL
        # without making real HTTP calls (unlike Google which uses OIDC discovery).
        req_conn = get(context.conn, "/auth/github")
        {:ok, Map.put(context, :oauth_req_conn, req_conn)}
      end

      then_ "they are redirected to GitHub's authorization endpoint", context do
        redirect_url = redirected_to(context.oauth_req_conn, 302)
        assert redirect_url =~ "github.com"
        {:ok, context}
      end
    end

    scenario "anonymous visitor sees GitHub sign-in on the registration page" do
      given_ "an anonymous visitor", context do
        {:ok, context}
      end

      when_ "they visit the registration page", context do
        {:ok, view, html} = live(context.conn, "/users/register")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a GitHub sign-in option is present on the registration page", context do
        assert has_element?(context.view, "[data-test='github-sign-in']"),
               "expected the GitHub sign-in button on /users/register so new visitors " <>
                 "can sign up in one click without navigating to /users/log-in first"

        {:ok, context}
      end

      then_ "the GitHub button links to the public sign-in route", context do
        assert has_element?(context.view, "a[href='/auth/github'][data-test='github-sign-in']")
        {:ok, context}
      end
    end

    scenario "callback creates a new user, logs them in, and redirects them home" do
      given_ "a brand-new GitHub identity returning a public email", context do
        unique = System.unique_integer([:positive])
        email = "new-dev-#{unique}@example.com"

        user_json = %{
          "id" => 99_500_000 + unique,
          "login" => "newdev#{unique}",
          "name" => "New Developer",
          "email" => email,
          "avatar_url" => "https://avatars.githubusercontent.com/u/0"
        }

        emails_json = [
          %{
            "email" => email,
            "primary" => true,
            "verified" => true,
            "visibility" => "public"
          }
        ]

        cassette = "github_5685_#{unique}"
        OAuthHelpers.build_github_cassette!(cassette, user_json, emails_json)

        # Pre-condition: no MMS user with this email yet.
        refute Users.get_user_by_email(email),
               "expected no pre-existing user for #{email} before the OAuth flow"

        {:ok,
         Map.merge(context, %{
           email: email,
           user_json: user_json,
           cassette: cassette
         })}
      end

      when_ "the GitHub OAuth callback completes via cassette replay", context do
        callback_conn =
          OAuthHelpers.do_github_callback(
            context.conn,
            context.cassette,
            "github-state-5685-#{System.unique_integer([:positive])}"
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

      then_ "a user record was created with the email GitHub returned", context do
        user = Users.get_user_by_email(context.email)

        assert user,
               "expected the OAuth callback to create a user with email #{context.email}"

        assert user.email == context.email
        {:ok, context}
      end
    end
  end
end
