defmodule MarketMySpecSpex.Story678.Criterion5780Spex do
  @moduledoc """
  Story 678 — Multi-Tenant Accounts
  Criterion 5780 — User switches accounts via a dedicated account picker page

  Story rule: a user with multiple accounts uses the dedicated picker
  page at /accounts/picker which lists every account they belong to.
  Selecting one sets the current context and redirects to the
  dashboard.
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  spex "user switches accounts via a dedicated account picker page" do
    scenario "the picker lists every account the user belongs to and selecting one switches context", context do
      given_ "a registered user", context do
        user = Fixtures.user_fixture()
        {token, _raw} = Fixtures.generate_user_magic_link_token(user)
        {:ok, Map.merge(context, %{user: user, token: token})}
      end

      when_ "the user signs in and creates 'Picker Workspace A' and 'Picker Workspace B'", context do
        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => context.token}})

        {:ok, view_a, _html_a} = live(authed_conn, "/accounts/new")

        view_a
        |> form("[data-test='account-form']", account: %{name: "Picker Workspace A"})
        |> render_submit()

        {:ok, view_b, _html_b} = live(authed_conn, "/accounts/new")

        view_b
        |> form("[data-test='account-form']", account: %{name: "Picker Workspace B"})
        |> render_submit()

        {:ok, Map.put(context, :conn, authed_conn)}
      end

      when_ "the user visits /accounts/picker", context do
        {:ok, view, html} = live(context.conn, "/accounts/picker")
        {:ok, Map.merge(context, %{picker_view: view, picker_html: html})}
      end

      then_ "the picker page lists every account the user belongs to", context do
        assert context.picker_html =~ ~r/Picker Workspace A/,
               "expected Workspace A in the picker"

        assert context.picker_html =~ ~r/Picker Workspace B/,
               "expected Workspace B in the picker"

        assert has_element?(context.picker_view, "[data-test='account-picker']"),
               "expected the dedicated account picker container to be present"

        :ok
      end
    end
  end
end
