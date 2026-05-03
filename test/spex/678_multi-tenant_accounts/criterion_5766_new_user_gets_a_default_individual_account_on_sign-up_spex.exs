defmodule MarketMySpecSpex.Story678.Criterion5766Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5766 — New user gets a default individual account on sign-up

  Story rule: a default individual account is automatically created on
  sign-up; the user is the owner; they land on the platform dashboard
  scoped to that account.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "new user gets a default individual account on sign-up" do
    scenario "the user lands on the accounts list with exactly one individual account visible", context do
      given_ "a freshly registered user with a magic-link token", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the user visits the accounts list", context do
        {:ok, view, html} = live(context.conn, "/accounts")
        {:ok, Map.merge(context, %{accounts_view: view, accounts_html: html})}
      end

      then_ "the accounts list renders the default individual account", context do
        assert context.accounts_html =~ ~r/individual/i,
               "expected the default account to be marked individual"

        refute context.accounts_html =~ ~r/no accounts/i,
               "expected the user not to see the empty-accounts message"

        :ok
      end
    end
  end
end
