defmodule MarketMySpecSpex.Story678.Criterion5767Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5767 — User with no account membership is redirected to account creation

  Story rule: a user must belong to at least one account before they can
  access any platform features. An authenticated user with zero accounts
  attempting any protected route is redirected to the account creation
  page; the dashboard is not rendered.

  Note: this scenario relies on a "user with zero accounts" fixture path
  that does not currently exist — the default user_fixture/1 auto-creates
  a default account. The scenario will fail until that fixture (or an
  account-less sign-up flow) is in place.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "user with no account membership is redirected to account creation" do
    scenario "a logged-in user with zero accounts is redirected away from a protected route" do
      given_ "a registered user with no account memberships", context do
        user = Fixtures.user_fixture(%{skip_default_account: true})
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "visiting /users/settings redirects to the account-creation entry point", context do
        assert {:error, {:live_redirect, %{to: "/accounts/new"}}} =
                 live(context.conn, "/users/settings")

        {:ok, context}
      end
    end
  end
end
