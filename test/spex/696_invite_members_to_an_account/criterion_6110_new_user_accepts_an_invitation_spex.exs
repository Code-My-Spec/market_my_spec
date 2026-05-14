defmodule MarketMySpecSpex.Story696.Criterion6110Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6110 — New user accepts an invitation

  An invitee who does not yet have an account visits the tokenized invitation
  link, sees the invitation details and an option to create an account, clicks
  the button, and is redirected to the login page after account creation.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "new user accepts an invitation", fail_on_error_logs: false do
    scenario "brand-new invitee visits the link, clicks create account, and is redirected" do
      given_ "an account owned by Alice with a pending invitation to newuser@example.com", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "newuser@example.com",
            :member
          )

        {:ok, Map.merge(context, %{alice: alice, account: account, invitation: invitation})}
      end

      when_ "the invitee visits the accept link and clicks 'Create Account & Accept Invitation'",
            context do
        {:ok, view, html} =
          live(context.conn, "/invitations/accept/#{context.invitation.token}")

        assert html =~ "Create Account" or html =~ "Create Your Account",
               "expected the create account card for a new user"

        result = view |> element("[phx-click='accept_invitation']") |> render_click()

        {:ok, Map.merge(context, %{accept_result: result})}
      end

      then_ "the invitee is redirected to the login page after account creation", context do
        # push_navigate to /users/log-in returns {:error, {:live_redirect, ...}}
        assert {:error, {:live_redirect, %{to: "/users/log-in"}}} = context.accept_result,
               "expected redirect to the login page after new user accepts the invitation"

        {:ok, context}
      end
    end
  end
end
