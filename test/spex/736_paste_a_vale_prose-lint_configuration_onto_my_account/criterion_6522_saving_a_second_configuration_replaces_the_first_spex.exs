defmodule MarketMySpecSpex.Story736.Criterion6522Spex do
  @moduledoc """
  Story 736 — Paste a Vale prose-lint configuration onto my account
  Criterion 6522 — Saving a second configuration replaces the first.

  Sam saves an initial .vale.ini. He returns later, pastes a different
  but still-valid .vale.ini, and submits. The new body replaces the
  old; a fresh mount shows the new body and none of the old one's
  distinguishing content.

  Interaction surface: LiveView (founder-facing web).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  @first_vale_ini """
  StylesPath = /app/priv/vale/styles
  MinAlertLevel = warning

  [*.md]
  BasedOnStyles = Vale
  """

  @second_vale_ini """
  StylesPath = /app/priv/vale/styles
  MinAlertLevel = suggestion

  [*.md]
  BasedOnStyles = Vale, write-good, proselint
  """

  spex "saving a second .vale.ini replaces the first" do
    scenario "Save config A → save config B → fresh mount shows B and not A" do
      given_ "Sam is logged in and has saved a first .vale.ini", context do
        sam = Fixtures.user_fixture()
        account = Fixtures.account_fixture(sam)
        {token, _} = Fixtures.generate_user_magic_link_token(sam)

        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(authed_conn, "/app/accounts/#{account.id}/style-guide")

        view
        |> form("[data-test='style-guide-form']", style_guide: %{vale_ini: @first_vale_ini})
        |> render_submit()

        {:ok, Map.merge(context, %{authed_conn: authed_conn, account: account})}
      end

      when_ "Sam pastes a different valid .vale.ini and submits", context do
        {:ok, view, _html} =
          live(context.authed_conn, "/app/accounts/#{context.account.id}/style-guide")

        view
        |> form("[data-test='style-guide-form']",
          style_guide: %{vale_ini: @second_vale_ini}
        )
        |> render_submit()

        {:ok, _fresh_view, fresh_html} =
          live(context.authed_conn, "/app/accounts/#{context.account.id}/style-guide")

        {:ok, Map.put(context, :fresh_html, fresh_html)}
      end

      then_ "fresh mount shows the new .vale.ini and none of the first's distinguishing content", context do
        assert context.fresh_html =~ "MinAlertLevel = suggestion",
               "expected new MinAlertLevel from second .vale.ini"

        assert context.fresh_html =~ "BasedOnStyles = Vale, write-good, proselint",
               "expected new BasedOnStyles list from second .vale.ini"

        refute context.fresh_html =~ "MinAlertLevel = warning",
               "expected first .vale.ini's MinAlertLevel to be gone"

        {:ok, context}
      end
    end
  end
end
