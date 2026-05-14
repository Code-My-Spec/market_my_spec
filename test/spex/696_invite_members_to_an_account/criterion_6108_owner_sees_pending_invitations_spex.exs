defmodule MarketMySpecSpex.Story696.Criterion6108Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6108 — Owner sees pending invitations

  When the account owner visits the invitations page, they see a list of
  all pending invitations for the account, including the invitee email,
  role, and who sent the invitation.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "owner sees pending invitations", fail_on_error_logs: false do
    scenario "owner visits invitations page and sees the pending invitation list" do
      given_ "an account with two pending invitations", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, _} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "bob@example.com",
            :member
          )

        {:ok, _} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "carol@example.com",
            :admin
          )

        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, account: account, token: token})}
      end

      when_ "Alice signs in and navigates to the invitations page", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, html} = live(authed_conn, "/accounts/#{context.account.id}/invitations")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "Alice sees both pending invitations listed with their details", context do
        html = render(context.view)

        assert html =~ "bob@example.com",
               "expected bob@example.com to appear in the pending invitations"

        assert html =~ "carol@example.com",
               "expected carol@example.com to appear in the pending invitations"

        assert html =~ "admin" or html =~ "Admin",
               "expected the admin role to be visible"

        {:ok, context}
      end
    end
  end
end
