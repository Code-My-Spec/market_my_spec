defmodule MarketMySpecSpex.Story678.Criterion5775Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5775 — Individual account does not show agency features
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "individual account does not show agency features" do
    scenario "user in an individual account does not see agency-only navigation or surfaces" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the user creates an individual account named 'Solo Workspace'", context do
        {:ok, view, _html} = live(context.conn, "/accounts/new")

        view
        |> form("[data-test='account-form']", account: %{name: "Solo Workspace"})
        |> render_submit()

        {:ok, context}
      end

      when_ "the user visits the accounts list", context do
        accounts_html =
          case live(context.conn, "/accounts") do
            {:ok, _view, html} -> html
            _ -> ""
          end

        {:ok, Map.put(context, :accounts_html, accounts_html)}
      end

      then_ "the accounts list shows the user's individual account", context do
        assert context.accounts_html != "", "expected accounts list to render"
        assert context.accounts_html =~ ~r/Solo Workspace/i,
               "expected individual account name in the accounts list"

        {:ok, context}
      end

      then_ "the individual-account UI does not expose agency-only feature affordances", context do
        assert context.accounts_html =~ ~r/Solo Workspace/i,
               "anchor: expected individual account to be visible"

        refute context.accounts_html =~ ~r/manage clients/i,
               "expected no 'manage clients' agency feature in individual UI"

        refute context.accounts_html =~ ~r/agency dashboard/i,
               "expected no 'agency dashboard' link in individual UI"

        {:ok, context}
      end
    end
  end
end
