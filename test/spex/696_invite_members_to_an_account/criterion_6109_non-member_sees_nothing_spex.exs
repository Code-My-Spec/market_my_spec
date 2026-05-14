defmodule MarketMySpecSpex.Story696.Criterion6109Spex do
  @moduledoc """
  Story 696 — Invite Members to an Account
  Criterion 6109 — Non-member sees nothing

  A user who is not a member of an account cannot access that account's
  invitations page — they are redirected away or the page is inaccessible.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "non-member sees nothing", fail_on_error_logs: false do
    scenario "a user who is not a member of an account cannot see its invitations" do
      given_ "an account owned by Alice and an unrelated user Dave", context do
        alice = Fixtures.user_fixture()
        dave = Fixtures.user_fixture()
        account = Fixtures.account_fixture(alice)
        {token, _} = Fixtures.generate_user_magic_link_token(dave)

        {:ok, Map.merge(context, %{alice: alice, dave: dave, account: account, token: token})}
      end

      when_ "Dave signs in and attempts to visit Alice's invitations page", context do
        authed_conn =
          post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        result = live(authed_conn, "/accounts/#{context.account.id}/invitations")

        {:ok, Map.merge(context, %{conn: authed_conn, mount_result: result})}
      end

      then_ "Dave is redirected away and cannot access the invitations list", context do
        case context.mount_result do
          {:error, {:redirect, %{to: redirect_to}}} ->
            refute redirect_to =~ "/accounts/#{context.account.id}/invitations",
                   "expected redirect away from the invitations page for a non-member"

            {:ok, context}

          {:error, {:live_redirect, %{to: redirect_to}}} ->
            refute redirect_to =~ "/accounts/#{context.account.id}/invitations",
                   "expected live_redirect away from the invitations page for a non-member"

            {:ok, context}

          {:ok, _view, _html} ->
            flunk("Expected non-member to be denied access to a different account's invitations")
        end
      end
    end
  end
end
