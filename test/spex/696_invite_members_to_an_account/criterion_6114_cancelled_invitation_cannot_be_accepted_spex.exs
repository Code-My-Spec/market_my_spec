defmodule MarketMySpecSpex.Story696.Criterion6114Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6114 — Cancelled invitation cannot be accepted

  After an invitation has been cancelled (status = :declined), visiting the
  accept URL with its token shows an "Invalid Invitation" error — the
  invitee cannot use the link to join the account.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "cancelled invitation cannot be accepted", fail_on_error_logs: false do
    scenario "invitee visits a cancelled invitation link and sees an invalid invitation error" do
      given_ "Alice's account had an invitation to bob@example.com that has been cancelled",
             context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "bob@example.com",
            :member
          )

        {:ok, _} =
          Accounts.cancel_invitation(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            invitation.id
          )

        {:ok,
         Map.merge(context, %{alice: alice, account: account, token: invitation.token})}
      end

      when_ "Bob visits the cancelled invitation's accept URL", context do
        {:ok, view, _html} = live(context.conn, "/invitations/accept/#{context.token}")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "Bob sees an Invalid Invitation error message", context do
        html = render(context.view)

        assert html =~ "Invalid Invitation" or
                 html =~ "invalid or has been cancelled" or
                 html =~ "invalid",
               "expected an error message indicating the invitation is no longer valid"

        {:ok, context}
      end
    end
  end
end
