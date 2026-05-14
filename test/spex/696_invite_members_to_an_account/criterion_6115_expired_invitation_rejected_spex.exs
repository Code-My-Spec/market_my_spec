defmodule MarketMySpecSpex.Story696.Criterion6115Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6115 — Expired invitation rejected

  When a visitor navigates to the accept URL with a token for an invitation
  whose `expires_at` is in the past, the page renders an "Expired Invitation"
  error message rather than allowing acceptance.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "expired invitation rejected", fail_on_error_logs: false do
    scenario "invitee visits an expired invitation link and sees an expired invitation error" do
      given_ "Alice's account has an invitation that has already expired", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "bob@example.com",
            :member
          )

        # Force-expire the invitation by setting expires_at to the past
        expired_at = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

        import Ecto.Query, only: [from: 2]

        MarketMySpec.Repo.update_all(
          from(i in MarketMySpec.Accounts.Invitation, where: i.id == ^invitation.id),
          set: [expires_at: expired_at]
        )

        {:ok,
         Map.merge(context, %{alice: alice, account: account, token: invitation.token})}
      end

      when_ "Bob visits the expired invitation's accept URL", context do
        {:ok, view, _html} = live(context.conn, "/invitations/accept/#{context.token}")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "Bob sees an Expired Invitation error message", context do
        html = render(context.view)

        assert html =~ "Expired Invitation" or
                 html =~ "expired" or
                 html =~ "request a new invitation",
               "expected an error message indicating the invitation has expired"

        {:ok, context}
      end
    end
  end
end
