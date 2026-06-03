defmodule MarketMySpecSpex.Story736.Criterion6521Spex do
  @moduledoc """
  Story 736 — Paste a Vale prose-lint configuration onto my account
  Criterion 6521 — Pasting malformed .vale.ini is rejected; prior
  configuration unchanged.

  Sam already has a saved .vale.ini on his Account. He pastes a new but
  malformed .vale.ini (one that fails `vale ls-config` validation). The
  page surfaces the validation error from `vale ls-config` and Sam's
  previously-saved configuration is preserved verbatim — both visible on
  a fresh mount.

  Interaction surface: LiveView (founder-facing web).
  """

  use MarketMySpecSpex.Case

  alias MarketMySpecSpex.Fixtures

  @prior_vale_ini """
  StylesPath = /app/priv/vale/styles
  MinAlertLevel = warning

  [*.md]
  BasedOnStyles = Vale
  """

  # Missing brackets around the format section header — `vale ls-config`
  # should reject this as a structural error.
  @malformed_vale_ini """
  StylesPath = /app/priv/vale/styles

  *.md
  BasedOnStyles = Vale
  """

  spex "malformed paste is rejected; prior configuration unchanged" do
    scenario "Sam has saved config → paste malformed → error surfaced; reload shows prior body" do
      given_ "Sam is logged in with a previously-saved valid .vale.ini", context do
        sam = Fixtures.user_fixture()
        account = Fixtures.account_fixture(sam)
        {token, _} = Fixtures.generate_user_magic_link_token(sam)

        authed_conn = post(context.conn, "/users/log-in", %{"user" => %{"token" => token}})

        {:ok, view, _html} = live(authed_conn, "/app/accounts/#{account.id}/style-guide")

        view
        |> form("[data-test='style-guide-form']", style_guide: %{vale_ini: @prior_vale_ini})
        |> render_submit()

        {:ok, Map.merge(context, %{authed_conn: authed_conn, account: account})}
      end

      when_ "Sam pastes a malformed .vale.ini and submits", context do
        {:ok, view, _html} =
          live(context.authed_conn, "/app/accounts/#{context.account.id}/style-guide")

        html_after_submit =
          view
          |> form("[data-test='style-guide-form']",
            style_guide: %{vale_ini: @malformed_vale_ini}
          )
          |> render_submit()

        {:ok, _fresh_view, fresh_html} =
          live(context.authed_conn, "/app/accounts/#{context.account.id}/style-guide")

        {:ok,
         Map.merge(context, %{
           html_after_submit: html_after_submit,
           fresh_html: fresh_html
         })}
      end

      then_ "the submit shows a validation error and the prior config is unchanged on reload", context do
        assert context.html_after_submit =~ "error" or
                 context.html_after_submit =~ "invalid" or
                 context.html_after_submit =~ "validation",
               "expected validation error surfaced from `vale ls-config` after malformed submit; got: #{context.html_after_submit}"

        assert context.fresh_html =~ "BasedOnStyles = Vale",
               "expected prior .vale.ini body preserved on reload after rejected paste"

        refute context.fresh_html =~ "*.md\n  BasedOnStyles",
               "expected malformed section header NOT persisted on reload"

        {:ok, context}
      end
    end
  end
end
