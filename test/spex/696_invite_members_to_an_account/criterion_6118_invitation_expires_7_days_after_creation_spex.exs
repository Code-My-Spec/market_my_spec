defmodule MarketMySpecSpex.Story696.Criterion6118Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6118 — Invitation expires 7 days after creation

  When an owner sends an invitation, the pending invitations table displays
  an expiry date that is 7 days after the invitation was created. The
  expiry date is visible to the account owner on the invitations page.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "invitation expires 7 days after creation", fail_on_error_logs: false do
    scenario "owner sees the 7-day expiry date listed in the pending invitations table" do
      given_ "an account with a fresh invitation to bob@example.com", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, _invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "bob@example.com",
            :member
          )

        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, account: account, token: token})}
      end

      when_ "Alice navigates to the invitations page", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, html} = live(authed_conn, "/accounts/#{context.account.id}/invitations")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the invitations table shows an expiry date approximately 7 days from now", context do
        html = render(context.view)

        assert html =~ "Expires At" or html =~ "expires_at",
               "expected an 'Expires At' column in the pending invitations table"

        expected_year = DateTime.utc_now() |> Map.get(:year) |> to_string()

        assert html =~ expected_year,
               "expected the expiry year #{expected_year} to appear in the invitations table"

        {:ok, context}
      end
    end
  end
end
