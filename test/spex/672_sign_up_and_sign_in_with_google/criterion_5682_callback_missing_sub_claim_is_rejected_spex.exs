defmodule MarketMySpecSpex.Story672.Criterion5682Spex do
  @moduledoc """
  Story 672 — Sign Up And Sign In With Google
  Criterion 5682 — Callback missing sub claim is rejected

  Quality gate: Google's `sub` is the stable account identifier. A token
  response whose id_token claims lack `sub` must be rejected — no user is
  created and the visitor is bounced back to `/users/log-in` with an
  error flash.

  Exercised through ReqCassette: a fresh id_token is signed with claims
  that intentionally omit `sub`, and Assent's Google strategy replays the
  full OIDC flow against the cassette. The rejection happens in
  `MarketMySpec.Integrations.Providers.Google.normalize_user/1`, which
  returns `{:error, :missing_provider_user_id}` and falls through to the
  generic OAuth-failure handler.

  `fail_on_error_logs: false` because the controller logs at :error level
  on this rejection path — that's the expected behavior, not a test failure.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Users
  alias MarketMySpecSpex.OAuthHelpers

  spex "callback missing sub claim is rejected", fail_on_error_logs: false do
    scenario "id_token without a sub claim is rejected before any user is created" do
      given_ "a Google callback whose id_token claims lack a sub", context do
        unique = System.unique_integer([:positive])
        email = "no-sub-#{unique}@example.com"

        # Note: no "sub" key.
        user_claims = %{
          "email" => email,
          "email_verified" => true,
          "name" => "No Sub User"
        }

        cassette = "google_5682_#{unique}"
        OAuthHelpers.build_google_cassette!(cassette, user_claims)

        refute Users.get_user_by_email(email),
               "expected no pre-existing user for #{email}"

        {:ok, Map.merge(context, %{email: email, cassette: cassette})}
      end

      when_ "the Google OAuth callback runs against the cassette", context do
        callback_conn =
          OAuthHelpers.do_google_callback(
            context.conn,
            context.cassette,
            "google-state-5682-#{System.unique_integer([:positive])}"
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
        assert error_flash =~ ~r/google.*fail|fail.*google/i,
               "expected the error flash to mention Google failure; got: #{inspect(error_flash)}"

        {:ok, context}
      end

      then_ "no user record was created for the rejected callback", context do
        refute Users.get_user_by_email(context.email),
               "expected NO user to be created when the sub claim is missing — " <>
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
