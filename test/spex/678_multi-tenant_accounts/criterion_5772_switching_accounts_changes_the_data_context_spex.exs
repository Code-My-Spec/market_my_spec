defmodule MarketMySpecSpex.Story678.Criterion5772Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5772 — Switching accounts changes the data context

  Story rule: a user with multiple accounts operates within exactly one
  current account context at a time; all reads and writes are scoped to
  that context. Switching to a different account makes the previous
  account's data invisible.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "switching accounts changes the data context" do
    scenario "user with two accounts switches via the picker and the visible data context changes" do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in via magic link", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})
        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the user creates 'Workspace A' and 'Workspace B'", context do
        {:ok, view_a, _html_a} = live(context.conn, "/accounts/new")

        view_a
        |> form("[data-test='account-form']", account: %{name: "Workspace A"})
        |> render_submit()

        {:ok, view_b, _html_b} = live(context.conn, "/accounts/new")

        view_b
        |> form("[data-test='account-form']", account: %{name: "Workspace B"})
        |> render_submit()

        {:ok, context}
      end

      when_ "the user opens the picker and selects 'Workspace B'", context do
        {:ok, picker_view, picker_html} = live(context.conn, "/accounts/picker")

        picker_view
        |> element("[data-test='account-picker-item-workspace-b']")
        |> render_click()

        {:ok, Map.put(context, :picker_html, picker_html)}
      end

      then_ "the picker lists both workspaces", context do
        assert context.picker_html =~ ~r/Workspace A/,
               "expected Workspace A to be visible in the picker"

        assert context.picker_html =~ ~r/Workspace B/,
               "expected Workspace B to be visible in the picker"

        {:ok, context}
      end

      then_ "after switching, the dashboard is scoped to Workspace B", context do
        {:ok, _view, dashboard_html} = live(context.conn, "/accounts")

        assert dashboard_html =~ ~r/Workspace B/,
               "expected the dashboard to render Workspace B context after switching"

        assert dashboard_html =~ ~r/data-test=['"]current-account['"][^>]*>[^<]*Workspace B/i,
               "expected current-account marker to identify Workspace B"

        {:ok, context}
      end
    end
  end
end
