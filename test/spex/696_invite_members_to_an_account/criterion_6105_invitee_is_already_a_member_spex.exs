defmodule MarketMySpecSpex.Story696.Criterion6105Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6105 — Invitee is already a member

  When an owner tries to invite an email address that already belongs to a
  member of the account, the form displays an error and the invitation is
  not sent.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "invitee is already a member", fail_on_error_logs: false do
    scenario "owner tries to invite an existing member and sees an error" do
      given_ "an account owned by Alice with Bob already as a member", context do
        alice = Fixtures.user_fixture()
        bob = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)
        Fixtures.account_member_fixture(account, bob, role: "member")
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, bob: bob, account: account, token: token})}
      end

      when_ "Alice opens the invite form and submits Bob's email", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} =
          live(authed_conn, "/accounts/#{context.account.id}/invitations")

        view
        |> element("[phx-click='toggle_invite_form']")
        |> render_click()

        view
        |> form("#invite-form", invitation: %{email: context.bob.email, role: "member"})
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "Alice sees an error message indicating Bob is already a member", context do
        html = render(context.view)

        assert html =~ "User already has access to this account" or
                 html =~ "already has access" or
                 html =~ "already a member",
               "expected an error about the invitee already being a member"

        {:ok, context}
      end
    end
  end
end
