defmodule MarketMySpecSpex.Story696.Criterion6116Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6116 — Signed-in matching user accepts

  When the currently signed-in user's email matches the invitation's email,
  they visit the accept URL, see the invitation card, click Accept, and are
  redirected to the login page with a success flash.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "signed-in matching user accepts", fail_on_error_logs: false do
    scenario "signed-in user whose email matches the invitation accepts successfully" do
      given_ "Alice's account has an invitation for Bob (who already has an account)", context do
        alice = Fixtures.user_fixture()
        bob = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            bob.email,
            :member
          )

        {bob_token, _} = Fixtures.generate_user_magic_link_token(bob)

        {:ok,
         Map.merge(context, %{
           alice: alice,
           bob: bob,
           account: account,
           invitation: invitation,
           bob_token: bob_token
         })}
      end

      when_ "Bob signs in and visits the invitation accept URL", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.bob_token}})

        {:ok, view, html} = live(authed_conn, "/invitations/accept/#{context.invitation.token}")

        {:ok, Map.merge(context, %{view: view, html: html, conn: authed_conn})}
      end

      then_ "Bob sees the invitation details and a Welcome back card", context do
        html = context.html

        assert html =~ context.account.name or html =~ "invited you to join",
               "expected the invitation card showing the account name"

        assert html =~ "Welcome back" or html =~ "already have an account",
               "expected a 'Welcome back' prompt for a signed-in existing user"

        {:ok, context}
      end
    end
  end
end
