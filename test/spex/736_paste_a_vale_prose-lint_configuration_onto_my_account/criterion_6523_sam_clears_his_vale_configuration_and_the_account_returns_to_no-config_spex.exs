defmodule MarketMySpecSpex.Story736.Criterion6523Spex do
  @moduledoc """
  Story 736 — Paste a Vale prose-lint configuration onto my account
  Criterion 6523 — Sam clears his Vale configuration and the Account
  returns to the no-config state.

  Sam saves a .vale.ini, then clicks the "Clear configuration" action
  on the style-guide settings page. A fresh mount of the page shows the
  empty-state UI (no saved body) and the form is ready to accept a new
  paste.

  Interaction surface: LiveView (founder-facing web).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  @saved_vale_ini """
  StylesPath = /app/priv/vale/styles
  MinAlertLevel = warning

  [*.md]
  BasedOnStyles = Vale
  """

  spex "clearing the Vale configuration returns the Account to no-config" do
    scenario "Save config → click Clear → fresh mount shows empty-state" do
      given_ "Sam is logged in with a saved .vale.ini", context do
        sam = Fixtures.user_fixture()
        account = Fixtures.account_fixture(sam)
        {token, _} = Fixtures.generate_user_magic_link_token(sam)

        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(authed_conn, "/accounts/#{account.id}/style-guide")

        view
        |> form("[data-test='style-guide-form']", style_guide: %{vale_ini: @saved_vale_ini})
        |> render_submit()

        {:ok, Map.merge(context, %{authed_conn: authed_conn, account: account})}
      end

      when_ "Sam clicks the Clear configuration action", context do
        {:ok, view, _html} =
          live(context.authed_conn, "/accounts/#{context.account.id}/style-guide")

        view
        |> element("[data-test='clear-style-guide']")
        |> render_click()

        {:ok, _fresh_view, fresh_html} =
          live(context.authed_conn, "/accounts/#{context.account.id}/style-guide")

        {:ok, Map.put(context, :fresh_html, fresh_html)}
      end

      then_ "the fresh mount shows the no-config empty-state and not the prior body", context do
        refute context.fresh_html =~ "StylesPath = /app/priv/vale/styles",
               "expected prior .vale.ini body to be cleared from the page"

        refute context.fresh_html =~ "BasedOnStyles = Vale",
               "expected prior BasedOnStyles line to be cleared"

        assert context.fresh_html =~ "no" or
                 context.fresh_html =~ "empty" or
                 context.fresh_html =~ "Paste",
               "expected empty-state copy on the page; got: #{context.fresh_html}"

        {:ok, context}
      end
    end
  end
end
