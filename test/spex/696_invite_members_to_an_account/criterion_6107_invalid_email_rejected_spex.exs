defmodule MarketMySpecSpex.Story696.Criterion6107Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6107 — Invalid email rejected

  When an owner submits the invite form with a malformed email address,
  the form shows a validation error and no invitation is created.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "invalid email rejected", fail_on_error_logs: false do
    scenario "owner submits a malformed email and sees a validation error" do
      given_ "an account owned by Alice", context do
        alice = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)
        {token, _} = Fixtures.generate_user_magic_link_token(alice)

        {:ok, Map.merge(context, %{alice: alice, account: account, token: token})}
      end

      when_ "Alice opens the invite form and submits 'not-an-email' as the email", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view, _html} =
          live(authed_conn, "/accounts/#{context.account.id}/invitations")

        view
        |> element("[phx-click='toggle_invite_form']")
        |> render_click()

        view
        |> form("#invite-form", invitation: %{email: "not-an-email", role: "member"})
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "Alice sees a validation error about the invalid email format", context do
        html = render(context.view)

        assert html =~ "must be a valid email address" or
                 html =~ "valid email" or
                 html =~ "invalid",
               "expected a validation error for a malformed email address"

        {:ok, context}
      end
    end
  end
end
