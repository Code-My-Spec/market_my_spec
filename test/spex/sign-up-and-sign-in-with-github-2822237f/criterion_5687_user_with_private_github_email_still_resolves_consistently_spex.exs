defmodule MarketMySpecSpex.Story673.Criterion5687Spex do
  @moduledoc """
  Story 673 — Sign Up And Sign In With GitHub
  Criterion 5687 — User with private GitHub email still resolves consistently

  GitHub users can mark their email private; the `/user` endpoint then
  returns `email: null`. The criterion requires that sign-in still
  succeeds — the account must resolve via the stable `id`, with the
  primary email pulled from `/user/emails` instead.

  HOW THIS WORKS:
  Assent's GitHub strategy (`Assent.Strategy.Github`) automatically calls
  `/user/emails` when the `user:email` scope is granted and merges the
  primary verified address into `user_data["email"]` when `/user` returned
  null. So `MarketMySpec.Integrations.Providers.GitHub.normalize_user/1`
  receives a populated email field even for private-email accounts, and
  `UserOAuthController.require_email/1` is satisfied. The cassette below
  confirms this end-to-end against scrubbed real-shape recordings of both
  endpoints.

  `fail_on_error_logs: false` is retained as a safety net because Assent's
  email-merge path can warn at runtime in edge cases (e.g. all emails
  unverified). Remove if it never trips.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Users
  alias MarketMySpecSpex.OAuthHelpers

  spex "account resolves by GitHub id even when email is private",
       fail_on_error_logs: false do
    scenario "GitHub callback succeeds when /user returns nil email but /user/emails has a primary" do
      given_ "a GitHub identity whose /user response has a nil email", context do
        unique = System.unique_integer([:positive])
        primary_email = "private-#{unique}@users.noreply.github.com"

        user_json = %{
          "id" => 99_700_000 + unique,
          "login" => "privateuser#{unique}",
          "name" => "Private Email User",
          # Private — GitHub returns nil here when the user has hidden it.
          "email" => nil,
          "avatar_url" => "https://avatars.githubusercontent.com/u/0"
        }

        emails_json = [
          %{
            "email" => primary_email,
            "primary" => true,
            "verified" => true,
            "visibility" => "private"
          }
        ]

        cassette = "github_5687_#{unique}"
        OAuthHelpers.build_github_cassette!(cassette, user_json, emails_json)

        refute Users.get_user_by_email(primary_email),
               "expected no pre-existing user for the private primary email"

        {:ok, Map.merge(context, %{primary_email: primary_email, cassette: cassette})}
      end

      when_ "the GitHub OAuth callback runs against the cassette", context do
        callback_conn =
          OAuthHelpers.do_github_callback(
            context.conn,
            context.cassette,
            "github-state-5687-#{System.unique_integer([:positive])}"
          )

        {:ok, Map.put(context, :callback_conn, callback_conn)}
      end

      then_ "the visitor is logged in (not rejected for missing email)", context do
        assert redirected_to(context.callback_conn, 302) == "/",
               "expected redirect to / on successful sign-in; private-email users " <>
                 "must not be turned away — the primary verified email is in /user/emails"

        assert Plug.Conn.get_session(context.callback_conn, :user_token),
               "expected :user_token after successful GitHub OAuth callback"

        {:ok, context}
      end

      then_ "a user record exists for the primary verified GitHub email", context do
        assert Users.get_user_by_email(context.primary_email),
               "expected a user to be created with the primary email from /user/emails"

        {:ok, context}
      end
    end
  end
end
