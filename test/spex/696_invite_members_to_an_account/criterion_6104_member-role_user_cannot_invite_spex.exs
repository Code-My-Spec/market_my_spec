defmodule MarketMySpecSpex.Story696.Criterion6104Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6104 — Member-role user cannot invite

  A user with the :member role on an account does not see the invite form
  and cannot send invitations to that account.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "member-role user cannot invite", fail_on_error_logs: false do
    scenario "member visits the invitations page and sees no invite button" do
      given_ "an account owned by Alice with Bob as a member", context do
        alice = Fixtures.user_fixture()
        bob = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)
        Fixtures.account_member_fixture(account, bob, role: "member")
        {token, _} = Fixtures.generate_user_magic_link_token(bob)

        {:ok, Map.merge(context, %{bob: bob, account: account, token: token})}
      end

      when_ "Bob signs in and visits the invitations page", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        result = live(authed_conn, "/accounts/#{context.account.id}/invitations")

        {:ok, Map.merge(context, %{conn: authed_conn, mount_result: result})}
      end

      then_ "Bob does not see the Invite Member button", context do
        case context.mount_result do
          {:error, {:redirect, _}} ->
            # Redirected away is also acceptable — member has no access
            {:ok, context}

          {:error, {:live_redirect, _}} ->
            {:ok, context}

          {:ok, view, _html} ->
            refute has_element?(view, "[phx-click='toggle_invite_form']"),
                   "expected no Invite Member button for a member-role user"

            {:ok, context}
        end
      end
    end
  end
end
