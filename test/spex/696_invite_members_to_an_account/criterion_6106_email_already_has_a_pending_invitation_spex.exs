defmodule MarketMySpecSpex.Story696.Criterion6106Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6106 — Email already has a pending invitation

  When an owner tries to invite an email address that already has a pending
  invitation to the same account, the form displays an error and a duplicate
  invitation is not created.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpec.Accounts
  alias MarketMySpec.Users.Scope
  alias MarketMySpecSpex.Fixtures

  spex "email already has a pending invitation", fail_on_error_logs: false do
    scenario "owner invites the same email twice and sees a duplicate error" do
      given_ "an account owned by Alice with a pending invitation to carol@example.com", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)

        {:ok, _invitation} =
          Accounts.invite_user(
            %Scope{user: alice, active_account_id: account.id},
            account.id,
            "carol@example.com",
            :member
          )

        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, account: account, token: token})}
      end

      when_ "Alice opens the invite form and submits carol@example.com again", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} =
          live(authed_conn, "/accounts/#{context.account.id}/invitations")

        view
        |> element("[phx-click='toggle_invite_form']")
        |> render_click()

        view
        |> form("#invite-form", invitation: %{email: "carol@example.com", role: "member"})
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "Alice sees an error indicating a pending invitation already exists", context do
        html = render(context.view)

        assert html =~ "An invitation is already pending for this email" or
                 html =~ "already pending" or
                 html =~ "already has a pending",
               "expected an error about the duplicate pending invitation"

        {:ok, context}
      end
    end
  end
end
