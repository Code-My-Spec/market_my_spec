defmodule MarketMySpecSpex.Story678.Criterion5767Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5767 — User with no account membership is redirected to account creation

  Story rule: a user must belong to at least one account before they can
  access any platform features. An authenticated user with zero accounts
  attempting any protected route is redirected to the account creation
  page; the dashboard is not rendered.

  The account-creation entry point is `/app`, not `/app/accounts/new`:
  since the onboarding change (`40d3c1d`) a user with no account lands on
  the `/app` overview, which forces workspace creation inline.
  `/app/accounts/new` is the bare CRUD form kept for the "create another
  workspace" flow. What this criterion pins is that a protected route
  cannot render for an account-less user — not which URL does the asking.
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
        assert {:error, {:live_redirect, %{to: "/app", flash: flash}}} =
                 live(context.conn, "/app/users/settings")

        assert flash["info"] =~ ~r/workspace/i,
               "expected the redirect to explain that a workspace is required; got: " <>
                 inspect(flash)

        {:ok, context}
      end
    end
  end
end
