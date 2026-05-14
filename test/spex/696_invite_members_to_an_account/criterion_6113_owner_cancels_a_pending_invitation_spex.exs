defmodule MarketMySpecSpex.Story696.Criterion6113Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6113 — Owner cancels a pending invitation

  An account owner opens the invitations page, clicks the Cancel button on
  a pending invitation, confirms the action in the modal, and the invitation
  is removed from the pending list.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "owner cancels a pending invitation", fail_on_error_logs: false do
    scenario "owner confirms cancel on a pending invitation and it disappears from the list" do
      given_ "an account with a pending invitation to bob@example.com", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "bob@example.com",
            :member
          )

        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok,
         Map.merge(context, %{alice: alice, account: account, invitation: invitation, token: token})}
      end

      when_ "Alice signs in, opens the invitations page, and confirms cancellation via the modal",
            context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} =
          live(authed_conn, "/accounts/#{context.account.id}/invitations")

        # Click the confirm button inside the cancel modal.
        # The confirm button has data-test="cancel-invitation-modal-{id}-confirm"
        # and sends phx-click="cancel_invitation" to the PendingInvitations component.
        modal_confirm_selector =
          "[data-test='cancel-invitation-modal-#{context.invitation.id}-confirm']"

        view
        |> element(modal_confirm_selector)
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "Bob's invitation no longer appears in the pending list", context do
        html = render(context.view)

        refute html =~ "bob@example.com",
               "expected bob@example.com to be removed from pending invitations after cancellation"

        {:ok, context}
      end
    end
  end
end
