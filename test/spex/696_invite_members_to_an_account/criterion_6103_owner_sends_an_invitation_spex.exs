defmodule MarketMySpecSpex.Story696.Criterion6103Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6103 — Owner sends an invitation

  An account owner opens the invitations page, fills in an email and role,
  submits the form, and sees the invitation listed as pending.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "owner sends an invitation", fail_on_error_logs: false do
    scenario "owner submits invite form and sees the invitation in the pending list" do
      given_ "an account owned by Alice", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, account: account, token: token})}
      end

      when_ "Alice signs in and submits an invitation for bob@example.com as member", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} =
          live(authed_conn, "/accounts/#{context.account.id}/invitations")

        view
        |> element("[phx-click='toggle_invite_form']")
        |> render_click()

        view
        |> form("#invite-form", invitation: %{email: "bob@example.com", role: "member"})
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the invitation for bob@example.com appears in the pending invitations table", context do
        html = render(context.view)
        assert html =~ "bob@example.com", "expected invited email to appear in pending invitations"
        assert html =~ "member" or html =~ "Member", "expected role to appear in pending invitations"
        {:ok, context}
      end
    end
  end
end
