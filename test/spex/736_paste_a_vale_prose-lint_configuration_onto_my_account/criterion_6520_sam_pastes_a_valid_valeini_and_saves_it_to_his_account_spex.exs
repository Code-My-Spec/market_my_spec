defmodule MarketMySpecSpex.Story736.Criterion6520Spex do
  @moduledoc """
  Story 736 — Paste a Vale prose-lint configuration onto my account
  Criterion 6520 — Sam pastes a valid .vale.ini and saves it to his Account.

  Sam visits his account's style-guide settings page, pastes a valid
  .vale.ini body into the form's textarea, and submits. The page re-renders
  showing the saved configuration body and a success flash. The persisted
  state is visible on a fresh mount of the same route.

  Interaction surface: LiveView (founder-facing web).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  @valid_vale_ini """
  StylesPath = /app/priv/vale/styles
  MinAlertLevel = warning

  [*.md]
  BasedOnStyles = Vale, write-good
  """

  spex "Sam pastes a valid .vale.ini and the body is persisted on his Account" do
    scenario "Empty config → paste valid .vale.ini → submit → fresh mount shows the saved body" do
      given_ "Sam is logged in and has no Vale config saved yet", context do
        sam = Fixtures.user_fixture()
        account = Fixtures.account_fixture(sam)
        {token, _} = Fixtures.generate_user_magic_link_token(sam)

        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, Map.merge(context, %{authed_conn: authed_conn, account: account})}
      end

      when_ "Sam pastes the .vale.ini into the form and submits", context do
        {:ok, view, _html} =
          live(context.authed_conn, "/accounts/#{context.account.id}/style-guide")

        view
        |> form("[data-test='style-guide-form']",
          style_guide: %{vale_ini: @valid_vale_ini}
        )
        |> render_submit()

        {:ok, fresh_view, fresh_html} =
          live(context.authed_conn, "/accounts/#{context.account.id}/style-guide")

        {:ok, Map.merge(context, %{view: view, fresh_view: fresh_view, fresh_html: fresh_html})}
      end

      then_ "the page renders the saved .vale.ini body and a success flash", context do
        assert render(context.view) =~ "saved" or render(context.view) =~ "Saved",
               "expected success flash after submit; rendered: #{render(context.view)}"

        assert context.fresh_html =~ "StylesPath = /app/priv/vale/styles",
               "expected saved .vale.ini body present on fresh mount"

        assert context.fresh_html =~ "MinAlertLevel = warning",
               "expected saved MinAlertLevel present on fresh mount"

        {:ok, context}
      end
    end
  end
end
