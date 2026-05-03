defmodule MarketMySpecSpex.Story678.Criterion5779Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5779 — New user is sent to explicit account creation before reaching the dashboard

  Story rule: a new user with no account memberships is redirected to
  /accounts/new before any other authenticated route renders. The
  account creation page asks only for a name (no type selector).

  Note: this depends on a "skip default account" fixture path or a
  sign-up flow that does not auto-create the default individual
  account. Until that exists, this scenario fails.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "new user is sent to explicit account creation before the dashboard" do
    scenario "a fresh user with no accounts is redirected to /accounts/new on any authenticated route" do
      given_ "a freshly confirmed user with no account memberships", context do
        user = Fixtures.user_fixture(%{skip_default_account: true})
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      then_ "visiting /users/settings redirects to /accounts/new", context do
        assert {:error, {:live_redirect, %{to: "/accounts/new"}}} =
                 live(context.conn, "/users/settings")

        {:ok, context}
      end

      then_ "the account-creation page exposes a name field but no type selector", context do
        {:ok, view, _html} = live(context.conn, "/accounts/new")

        assert has_element?(view, "[data-test='account-form'] [name='account[name]']"),
               "expected name input on the account-creation form"

        refute has_element?(view, "[data-test='account-form'] [name='account[type]']"),
               "expected no account[type] selector on the self-service account-creation form"

        {:ok, context}
      end
    end
  end
end
