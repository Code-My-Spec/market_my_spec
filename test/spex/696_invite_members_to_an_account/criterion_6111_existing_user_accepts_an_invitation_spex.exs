defmodule MarketMySpecSpex.Story696.Criterion6111Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6111 — Existing user accepts an invitation

  An invitee who already has a MarketMySpec account visits the invitation
  link, sees a "Welcome back!" card, clicks Accept Invitation, and is
  redirected to the login page with a success flash.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "existing user accepts an invitation", fail_on_error_logs: false do
    scenario "existing invitee visits the link and accepts with a single button click" do
      given_ "Alice's account has a pending invitation for Bob (who already has an account)", context do
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

        {:ok, Map.merge(context, %{alice: alice, bob: bob, account: account, invitation: invitation})}
      end

      when_ "Bob visits the invite link as an existing user and clicks 'Accept Invitation'",
            context do
        {:ok, view, html} = live(context.conn, "/invitations/accept/#{context.invitation.token}")

        assert html =~ "Welcome back" or html =~ "already have an account",
               "expected the accept page to recognise Bob as an existing user"

        result = view |> element("[phx-click='accept_invitation']") |> render_click()

        {:ok, Map.merge(context, %{accept_result: result})}
      end

      then_ "Bob is redirected to the login page after successfully accepting", context do
        # push_navigate to /users/log-in produces {:error, {:live_redirect, ...}}
        assert {:error, {:live_redirect, %{to: "/users/log-in"}}} = context.accept_result,
               "expected redirect to the login page after existing user accepts the invitation"

        {:ok, context}
      end
    end
  end
end
