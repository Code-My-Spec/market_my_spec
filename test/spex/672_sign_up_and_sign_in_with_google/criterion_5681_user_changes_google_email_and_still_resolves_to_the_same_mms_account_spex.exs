defmodule MarketMySpecSpex.Story672.Criterion5681Spex do
  @moduledoc """
  Story 672 — Sign Up And Sign In With Google
  Criterion 5681 — User changes Google email and still resolves to the same MMS account

  Google's `sub` claim is the stable identifier. If a user changes their
  primary Google email, the second sign-in must resolve to the SAME MMS
  user record — not create a duplicate account keyed by the new email.

  HOW THIS WORKS:
  `UserOAuthController.handle_oauth_callback/4` resolves the user in this
  priority:

    1. By `(provider, provider_user_id)` via
       `Integrations.find_user_id_by_provider_identity/2` — the JSONB
       lookup on `integrations.provider_metadata->>'provider_user_id'`.
    2. By email — covers the "same person, different provider" case.
    3. Otherwise create a new user.

  After resolution the OAuth integration is upserted with
  `(user_id, provider)` as the conflict target, so the second callback
  refreshes tokens on the existing row instead of inserting a duplicate.
  This guarantees that a Google primary-email change produces no
  duplicate MMS account.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Users
  alias MarketMySpecSpex.OAuthHelpers

  spex "account resolves by Google sub even when email changes" do
    scenario "second Google callback with the same sub but a new email returns the original user" do
      given_ "an MMS user already created via Google sign-in", context do
        unique = System.unique_integer([:positive])
        sub = "google-sub-5681-#{unique}"
        original_email = "before-change-#{unique}@example.com"

        original_claims = %{
          "sub" => sub,
          "email" => original_email,
          "email_verified" => true,
          "name" => "Email Changer"
        }

        cassette_a = "google_5681_a_#{unique}"
        OAuthHelpers.build_google_cassette!(cassette_a, original_claims)

        first_conn =
          OAuthHelpers.do_google_callback(
            context.conn,
            cassette_a,
            "google-state-5681-a-#{unique}"
          )

        # Sanity: the first callback created a user.
        original_user = Users.get_user_by_email(original_email)
        assert original_user, "first callback should have created the original user"

        {:ok,
         Map.merge(context, %{
           sub: sub,
           original_email: original_email,
           original_user_id: original_user.id,
           first_conn: first_conn,
           unique: unique
         })}
      end

      when_ "Google returns a second callback with the same sub but a new email", context do
        new_email = "after-change-#{context.unique}@example.com"

        new_claims = %{
          "sub" => context.sub,
          "email" => new_email,
          "email_verified" => true,
          "name" => "Email Changer"
        }

        cassette_b = "google_5681_b_#{context.unique}"
        OAuthHelpers.build_google_cassette!(cassette_b, new_claims)

        second_conn =
          OAuthHelpers.do_google_callback(
            Phoenix.ConnTest.build_conn(),
            cassette_b,
            "google-state-5681-b-#{context.unique}"
          )

        {:ok, Map.merge(context, %{new_email: new_email, second_conn: second_conn})}
      end

      then_ "the second callback succeeds and logs the user in", context do
        assert redirected_to(context.second_conn, 302) == "/"

        assert Plug.Conn.get_session(context.second_conn, :user_token),
               "expected the second callback to log the user in"

        {:ok, context}
      end

      then_ "no duplicate user was created for the new email", context do
        # The desired behavior: the original user is the only Google-tied
        # user in the system; the new email points at the same record (or
        # was added as an alias). Today this fails because get_user_by_email
        # returns nil for new_email and a fresh user is created.
        original = Users.get_user!(context.original_user_id)
        assert original, "the original user must still exist"

        # Either the new email resolves to the original user, OR the
        # original user's email was updated. In neither case should a
        # SECOND user record exist.
        new_email_user = Users.get_user_by_email(context.new_email)

        if new_email_user do
          assert new_email_user.id == context.original_user_id,
                 "expected the new email to resolve to the same MMS user (id=#{context.original_user_id}); " <>
                   "instead found a different user id=#{new_email_user.id} — " <>
                   "this is the duplicate-account gap the criterion forbids"
        end

        {:ok, context}
      end
    end
  end
end
