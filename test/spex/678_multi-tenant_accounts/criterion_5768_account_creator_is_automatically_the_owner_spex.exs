defmodule MarketMySpecSpex.Story678.Criterion5768Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5768 — Account creator is automatically the owner

  Story rule: the user who creates an account is automatically assigned
  the owner role; an account_members record exists for that user with
  role "owner".
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "account creator is automatically the owner" do
    scenario "creating an account routes to the new account's manage page and lists the creator as owner", context do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the user creates a new account named 'Owner Test Workspace'", context do
        {:ok, view, _html} = live(context.conn, "/accounts/new")

        view
        |> form("[data-test='account-form']", account: %{name: "Owner Test Workspace"})
        |> render_submit()

        {:ok, Map.put(context, :form_view, view)}
      end

      then_ "the accounts list shows the new account labeled with the owner role", context do
        {:ok, _view, html} = live(context.conn, "/accounts")

        assert html =~ ~r/Owner Test Workspace/,
               "expected new account name in the accounts list"

        assert html =~ ~r/Owner Test Workspace[\s\S]{0,400}\bowner\b/i,
               "expected the owner role label co-located with the new account row"

        refute html =~ ~r/Owner Test Workspace[\s\S]{0,200}\bmember\b/i,
               "expected the creating user not to be labeled 'member' on the new account"

        :ok
      end
    end
  end
end
