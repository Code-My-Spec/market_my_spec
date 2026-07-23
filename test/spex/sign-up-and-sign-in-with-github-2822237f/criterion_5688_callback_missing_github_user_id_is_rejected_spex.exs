defmodule MarketMySpecSpex.Story673.Criterion5688Spex do
  @moduledoc """
  Story 673 — Sign Up And Sign In With GitHub
  Criterion 5688 — Callback missing GitHub user id is rejected

  Quality gate: GitHub's `id` is the stable account identifier. A `/user`
  response without an `id` (or `sub`) must be rejected — no user is
  created and the visitor is bounced back to `/users/log-in` with an
  error flash.

  Exercised through ReqCassette: the recorded `/user` response is
  rewritten to omit `id`, and Assent's GitHub strategy replays the
  flow against the cassette. The rejection happens in
  `MarketMySpec.Integrations.Providers.GitHub.normalize_user/1`, which
  returns `{:error, :missing_provider_user_id}` and falls through to the
  generic OAuth-failure handler.

  `fail_on_error_logs: false` because the controller logs at :error level
  on this rejection path — that's the expected behavior, not a test failure.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Users
  alias MarketMySpecSpex.OAuthHelpers

  spex "callback missing GitHub user id is rejected", fail_on_error_logs: false do
    scenario "user response without an id is rejected before any user is created" do
      given_ "a GitHub callback whose /user response lacks an id", context do
        unique = System.unique_integer([:positive])
        email = "no-id-#{unique}@example.com"

        # Note: no "id" or "sub" key.
        user_json = %{
          "login" => "noiduser#{unique}",
          "name" => "No ID User",
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

        cassette = "github_5688_#{unique}"
        OAuthHelpers.build_github_cassette!(cassette, user_json, emails_json)

        refute Users.get_user_by_email(email),
               "expected no pre-existing user for #{email}"

        {:ok, Map.merge(context, %{email: email, cassette: cassette})}
      end

      when_ "the GitHub OAuth callback runs against the cassette", context do
        callback_conn =
          OAuthHelpers.do_github_callback(
            context.conn,
            context.cassette,
            "github-state-5688-#{System.unique_integer([:positive])}"
          )

        {:ok, Map.put(context, :callback_conn, callback_conn)}
      end

      then_ "the visitor is redirected back to the log-in page", context do
        assert redirected_to(context.callback_conn, 302) == "/users/log-in",
               "expected redirect to /users/log-in on rejection; got: " <>
                 inspect(redirected_to(context.callback_conn, 302))

        {:ok, context}
      end

      then_ "an error flash explains the failure", context do
        error_flash = Phoenix.Flash.get(context.callback_conn.assigns.flash, :error)

        assert error_flash, "expected an error flash to be set on rejection"
        assert error_flash =~ ~r/github.*fail|fail.*github/i,
               "expected the error flash to mention GitHub failure; got: #{inspect(error_flash)}"

        {:ok, context}
      end

      then_ "no user record was created for the rejected callback", context do
        refute Users.get_user_by_email(context.email),
               "expected NO user to be created when the id is missing — " <>
                 "this is the quality gate the criterion enforces"

        {:ok, context}
      end

      then_ "the session does not carry a user_token", context do
        refute Plug.Conn.get_session(context.callback_conn, :user_token),
               "expected no :user_token after a rejected OAuth callback"

        {:ok, context}
      end
    end
  end
end
